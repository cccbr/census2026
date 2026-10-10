# catchment.R -----------------------------------------------------------------
#
# Distance-decay aggregation around towers. It measures how many people a tower
# "sees", and how many other towers and bells share them.
#
# CONTRACT: as for everything in R/, these functions take explicit inputs and
# return values. They do not read or write files.
#
# WHY A DECAY KERNEL, NOT A RADIUS
#   A hard radius gives full weight to a person 1.99 km away and no weight to
#   one 2.01 km away. So the radius choice and small coordinate errors move the
#   number. An exponential kernel has no cliff: weight halves every
#   `half_distance_m`, K(d) = 0.5^(d / h). Choosing a half-distance is still a
#   choice (D-026), but the result changes smoothly with it, not in steps.
#   Plain circular counts are computed as well (D-026), for simplicity of
#   communication rather than as the preferred measure.
#
# WHY GREAT-CIRCLE DISTANCES
#   GHSL publishes population in World Mollweide (ESRI:54009). Mollweide is
#   equal-area, so cell counts sum correctly. It is not equidistant. At 52°N on
#   the central meridian it stretches east-west distances by about 8% and
#   shrinks north-south distances by about 7%. Away from the meridian the
#   distortion also depends on direction. Over uniform population the errors
#   cancel, because the projection is equal-area. They do not cancel when a town
#   lies on one side of the tower, and that is the case that matters. Cell
#   centres are therefore projected back to longitude/latitude, and distances
#   are computed on the sphere. The method then works the same in Norfolk and
#   New South Wales.

EARTH_RADIUS_M <- 6371008.8   # IUGG mean radius

#' Great-circle distance in metres (haversine)
#'
#' Vectorised over all arguments.
haversine_m <- function(lon1, lat1, lon2, lat2) {
  rad  <- pi / 180
  dlat <- (lat2 - lat1) * rad
  dlon <- (lon2 - lon1) * rad
  a <- sin(dlat / 2)^2 + cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  2 * EARTH_RADIUS_M * asin(pmin(1, sqrt(a)))
}

#' Exponential decay weight that halves every `half_distance_m`
decay_weight <- function(d_m, half_distance_m) {
  0.5^(d_m / half_distance_m)
}

#' Truncation radius for an exponential kernel on a plane
#'
#' The kernel is evaluated only within a window, for speed. This gives the
#' radius beyond which less than `tol` of the kernel's mass lies, over a
#' uniform surface. For K(d) = exp(-lambda d) in two dimensions, the share of
#' mass beyond r is (1 + lambda r) exp(-lambda r). With tol = 0.01 the cutoff
#' is about 9.6 half-distances.
#'
#' The truncation is a tolerance, not a method choice: tightening `tol` should
#' move results only in the third significant figure. Check this once on real
#' data.
kernel_cutoff_m <- function(half_distance_m, tol = 0.01) {
  stopifnot(tol > 0, tol < 1)
  lambda <- log(2) / half_distance_m
  x <- stats::uniroot(\(x) (1 + x) * exp(-x) - tol, c(1e-9, 200))$root
  x / lambda
}

#' Points at distance `d_m` from (lon, lat) on a set of bearings
#'
#' Spherical destination-point formula. Used to draw a "circle" whose projected
#' bounding box sets a raster window.
destination_points <- function(lon, lat, d_m, n = 72) {
  brg   <- seq(0, 2 * pi, length.out = n + 1)[-1]
  rad   <- pi / 180
  phi1  <- lat * rad
  lam1  <- lon * rad
  delta <- d_m / EARTH_RADIUS_M
  phi2  <- asin(sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(brg))
  lam2  <- lam1 + atan2(sin(brg) * sin(delta) * cos(phi1),
                        cos(delta) - sin(phi1) * sin(phi2))
  cbind(lon = lam2 / rad, lat = phi2 / rad)
}

#' Bounding box, in a raster's CRS, of a geodesic circle around a point
#'
#' @return A terra SpatExtent.
window_extent <- function(lon, lat, radius_m, crs) {
  # Pad by 2% so that the bbox of 72 sampled points cannot fall short of the
  # true curve.
  ring <- destination_points(lon, lat, radius_m * 1.02)
  xy   <- sf::sf_project(from = "OGC:CRS84", to = crs, pts = ring)
  terra::ext(min(xy[, 1]), max(xy[, 1]), min(xy[, 2]), max(xy[, 2]))
}

#' Weight a set of distances for one measure
#'
#' Two measure types:
#'   "kernel"  exponential decay, halving every `param_m` metres (D-026)
#'   "radius"  a plain circular count: weight 1 within `param_m`, else 0. Kept
#'             alongside the kernels because a radius is easy to explain to a
#'             meeting, even though its edge is arbitrary.
measure_weight <- function(d_m, type, param_m) {
  switch(type,
    kernel = decay_weight(d_m, param_m),
    radius = as.numeric(d_m <= param_m),
    stop("Unknown measure type: ", type, call. = FALSE)
  )
}

#' How far out a measure needs to look
measure_reach_m <- function(type, param_m, tol = 0.01) {
  switch(type,
    kernel = kernel_cutoff_m(param_m, tol),
    radius = param_m,
    stop("Unknown measure type: ", type, call. = FALSE)
  )
}

#' Several distance-weighted sums of a count raster, around each point
#'
#' For each focal point, takes every raster cell whose centre is within reach,
#' weights its count by each measure in turn (great-circle distance), and sums.
#' All measures share one window per point, so adding a radius costs almost
#' nothing once a wider kernel is being computed anyway.
#'
#' Cells absent from the raster (NA) contribute nothing. This is deliberate.
#' GHSL does not publish ocean-only tiles, so a missing area is genuinely
#' unpopulated. The duty to have downloaded every tile that *does* exist
#' belongs to the fetch script, which records which tiles were absent upstream.
#'
#' @param lon,lat Focal coordinates, WGS84 degrees.
#' @param r SpatRaster of counts per cell, in a projected CRS.
#' @param measures Data frame with columns `measure` (output name), `type`
#'   ("kernel" or "radius") and `param_m`.
#' @param tol Kernel truncation tolerance, passed to `kernel_cutoff_m()`.
#' @return Tibble with one column per measure, one row per focal point.
raster_window_sums <- function(lon, lat, r, measures, tol = 0.01) {
  stopifnot(length(lon) == length(lat), terra::nlyr(r) == 1)
  reach <- purrr::map2_dbl(measures$type, measures$param_m, measure_reach_m, tol = tol)
  window <- max(reach)
  r_crs  <- terra::crs(r)
  r_ext  <- terra::ext(r)
  zero   <- rep(0, nrow(measures))

  one <- function(x0, y0) {
    win <- terra::intersect(window_extent(x0, y0, window, r_crs), r_ext)
    if (is.null(win)) return(zero)
    w <- terra::crop(r, win, snap = "out")
    v <- terra::values(w, mat = FALSE)
    cells <- which(!is.na(v) & v > 0)
    if (length(cells) == 0) return(zero)
    xy <- terra::xyFromCell(w, cells)
    ll <- sf::sf_project(from = r_crs, to = "OGC:CRS84", pts = xy)
    d  <- haversine_m(x0, y0, ll[, 1], ll[, 2])
    v  <- v[cells]
    vapply(seq_len(nrow(measures)), \(m) {
      keep <- d <= reach[m]
      sum(v[keep] * measure_weight(d[keep], measures$type[m], measures$param_m[m]))
    }, numeric(1))
  }

  out <- purrr::map2(lon, lat, one, .progress = "raster window sums")
  out <- matrix(unlist(out), ncol = nrow(measures), byrow = TRUE,
                dimnames = list(NULL, measures$measure))
  tibble::as_tibble(out)
}

#' Several distance-weighted sums of a point attribute, around each focal point
#'
#' For each focal point and each measure: the sum over source points j of
#' weight_j * w(d_ij), within that measure's reach.
#'
#' A source point at zero distance, such as the focal tower itself when it is
#' in the source set, IS included at full weight. Excluding it here would hide
#' a choice. Callers that want "other towers only" subtract the focal tower's
#' own weight explicitly, where the reader can see it.
#'
#' @param focal Data frame with `lon`, `lat`.
#' @param source Data frame with `lon`, `lat`, `weight`.
#' @param measures As for `raster_window_sums()`.
#' @return Tibble with one column per measure, one row per focal row.
point_window_sums <- function(focal, source, measures, tol = 0.01) {
  reach <- purrr::map2_dbl(measures$type, measures$param_m, measure_reach_m, tol = tol)
  f_sf <- sf::st_as_sf(focal,  coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  s_sf <- sf::st_as_sf(source, coords = c("lon", "lat"), crs = 4326, remove = FALSE)

  # Neighbour search only. Distances are recomputed with haversine_m() below,
  # so every measure uses one distance definition. The search uses a slightly
  # wider radius so that differences between s2's sphere and ours cannot drop
  # a pair at the edge.
  nb <- sf::st_is_within_distance(f_sf, s_sf, dist = max(reach) * 1.001)

  out <- purrr::map(seq_along(nb), \(i) {
    j <- nb[[i]]
    if (length(j) == 0) return(rep(0, nrow(measures)))
    d <- haversine_m(focal$lon[i], focal$lat[i], source$lon[j], source$lat[j])
    wt <- source$weight[j]
    vapply(seq_len(nrow(measures)), \(m) {
      keep <- d <= reach[m]
      sum(wt[keep] * measure_weight(d[keep], measures$type[m], measures$param_m[m]))
    }, numeric(1))
  })
  out <- matrix(unlist(out), ncol = nrow(measures), byrow = TRUE,
                dimnames = list(NULL, measures$measure))
  tibble::as_tibble(out)
}

#' Towers to enrich: every Dove tower in a country that has a frame ring
#'
#' This covers frame towers and also out-of-frame towers in the same countries
#' (rings of three, mini-rings, unringable towers). Responses from those
#' towers have no denominator (Q-017), but their context is still useful
#' descriptively. Countries with no frame ring are left out. That avoids
#' downloading population tiles for single towers in Kenya or Pakistan, and
#' adds no countries beyond those D-019 already admits.
#'
#' @param frame The curated frame, one row per ring.
#' @return Character vector of tower_id.
context_scope <- function(frame) {
  frame_countries <- unique(frame$country[frame$frame_full])
  frame |>
    dplyr::filter(.data$country %in% frame_countries) |>
    dplyr::distinct(.data$tower_id) |>
    dplyr::pull(.data$tower_id)
}

#' GHSL Degree of Urbanisation level-2 (SMOD) class labels
#'
#' Codes and labels as published by JRC for GHS-SMOD R2023A.
SMOD_L2_CLASSES <- tibble::tribble(
  ~smod_code, ~smod_class,                    ~smod_l1,
  30L,        "Urban centre",                 "Urban centre",
  23L,        "Dense urban cluster",          "Urban cluster",
  22L,        "Semi-dense urban cluster",     "Urban cluster",
  21L,        "Suburban or peri-urban",       "Urban cluster",
  13L,        "Rural cluster",                "Rural",
  12L,        "Low density rural",            "Rural",
  11L,        "Very low density rural",       "Rural",
  10L,        "Water",                        "Water"
)
