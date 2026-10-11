# contiguity.R ----------------------------------------------------------------
#
# The contiguous settlement each tower sits in, traced on the international
# Degree of Urbanisation grid (GHS-SMOD, 1 km cells).
#
# CONTRACT: as for everything in R/, these functions take explicit inputs and
# return values. They do not read or write files.
#
# WHY CONTIGUITY, AS WELL AS DISTANCE
#   The kernels and circles in catchment.R count everyone within reach, whether
#   or not they live in the same place as the tower. So a free-standing city
#   with green belt around it (St Albans) and a stretch of continuous suburb
#   (Staines) can score alike. What tells them apart is whether the built-up
#   area is continuous. The Degree of Urbanisation already traces that, so its
#   own rules are used here rather than new ones. In the words of the
#   methodological manual (Eurostat 2021, "Applying the Degree of
#   Urbanisation"):
#     urban centre:  "Contiguous cells (without diagonals and with gap
#                    filling) with a density of at least 1 500 inhabitants/km2
#                    and a minimum of 50 000 inhabitants"
#     urban cluster: "Contiguous cells (including diagonals) with a density of
#                    at least 300 inhabitants/km2 and a minimum of 5 000
#                    inhabitants"
#   GHS-SMOD has already applied these rules and labelled each cell. Here the
#   labelled cells are joined back into patches with the same connectivity, and
#   each patch's population is summed.
#
# WINDOWS
#   Patches are traced inside a window around each block of towers, not over
#   the whole world. A patch that touches the window's edge may be cut short,
#   and is flagged. With a 75 km margin this should only happen for the
#   largest conurbations, whose size is then a lower bound.

#' One labelled raster turned into contiguous patches of the given codes
#'
#' @return list(id = patch id per cell, pop = population per patch,
#'   cells = cells per patch, edge = patch ids touching the window edge)
trace_patches <- function(codes_r, pop_v, codes, directions) {
  v <- terra::values(codes_r, mat = FALSE)
  keep <- terra::setValues(codes_r, ifelse(v %in% codes, 1L, NA_integer_))
  pt <- terra::patches(keep, directions = directions, zeroAsNA = FALSE)
  id <- terra::values(pt, mat = FALSE)
  has <- !is.na(id)
  pop   <- if (any(has)) tapply(pop_v[has], id[has], sum) else numeric(0)
  cells <- if (any(has)) tapply(id[has], id[has], length) else numeric(0)
  nr <- terra::nrow(codes_r); nc <- terra::ncol(codes_r)
  rc <- terra::rowColFromCell(codes_r, which(has))
  on_edge <- rc[, 1] %in% c(1, nr) | rc[, 2] %in% c(1, nc)
  list(id = id, pop = pop, cells = cells,
       edge = unique(id[which(has)[on_edge]]))
}

#' Contiguous settlement measures for each tower
#'
#' @param lon,lat Tower coordinates, WGS84 degrees.
#' @param smod GHS-SMOD level 2 SpatRaster (codes as in SMOD_L2_CLASSES).
#' @param pop Population SpatRaster on the same 1 km grid as `smod`.
#' @param layers Tibble with `name`, `codes` (list column) and `directions`
#'   (4 = without diagonals, 8 = including diagonals).
#' @param nearest Name of the layer whose nearest patch is also reported
#'   (distance and population), or NULL.
#' @param half_width_m Margin around each block of towers.
#' @param block_m Towers are grouped into square blocks of this size, and each
#'   block's window is traced once.
#' @return Tibble, one row per tower: `<name>_pop`, `<name>_km2` for each
#'   layer (NA where the tower's cell is not in such a patch), `<nearest>_dist_km`,
#'   `<nearest>_nearest_pop`, and `settlement_window_edge` (TRUE if any patch
#'   reported for the tower touched its window's edge).
contiguous_settlements <- function(lon, lat, smod, pop, layers, nearest = NULL,
                                   half_width_m = 75000, block_m = 50000) {
  stopifnot(length(lon) == length(lat))
  # The two rasters must share one grid. GHSL publishes them on the same
  # Mollweide 1 km lattice; check rather than assume.
  if (!isTRUE(all.equal(terra::res(smod), terra::res(pop))) ||
      any(abs(terra::origin(smod) - terra::origin(pop)) > 1)) {
    stop("SMOD and population rasters are not on the same grid: res ",
         paste(terra::res(smod), collapse = "x"), " vs ", paste(terra::res(pop), collapse = "x"),
         "; origin ", paste(terra::origin(smod), collapse = ","), " vs ",
         paste(terra::origin(pop), collapse = ","), call. = FALSE)
  }
  crs <- terra::crs(smod)
  xy <- sf::sf_project("OGC:CRS84", crs, cbind(lon, lat))
  n <- length(lon)
  block <- paste(floor(xy[, 1] / block_m), floor(xy[, 2] / block_m))

  out <- list()
  for (nm in layers$name) {
    out[[paste0(nm, "_pop")]] <- rep(NA_real_, n)
    out[[paste0(nm, "_km2")]] <- rep(NA_real_, n)
  }
  if (!is.null(nearest)) {
    out[[paste0(nearest, "_dist_km")]]     <- rep(NA_real_, n)
    out[[paste0(nearest, "_nearest_pop")]] <- rep(NA_real_, n)
  }
  out$settlement_window_edge <- rep(FALSE, n)

  for (b in unique(block)) {
    i <- which(block == b)
    e <- terra::ext(min(xy[i, 1]) - half_width_m, max(xy[i, 1]) + half_width_m,
                    min(xy[i, 2]) - half_width_m, max(xy[i, 2]) + half_width_m)
    e <- terra::intersect(e, terra::ext(smod))
    if (is.null(e)) next
    s <- terra::crop(smod, e, snap = "out")

    # Population on exactly the same cells. Cells outside the downloaded tiles
    # are absent from the population raster and count as zero, as they do in
    # the distance measures.
    pe <- terra::intersect(terra::ext(s), terra::ext(pop))
    p <- if (is.null(pe)) {
      terra::setValues(s, 0)
    } else {
      terra::crop(terra::extend(terra::crop(pop, pe, snap = "out"), s), s)
    }
    if (!terra::compareGeom(s, p, stopOnError = FALSE)) {
      stop("Population window does not match the SMOD window for block ", b, call. = FALSE)
    }
    pop_v <- terra::values(p, mat = FALSE)
    pop_v[is.na(pop_v)] <- 0
    cell <- terra::cellFromXY(s, xy[i, , drop = FALSE])

    for (k in seq_len(nrow(layers))) {
      nm <- layers$name[k]
      tr <- trace_patches(s, pop_v, layers$codes[[k]], layers$directions[k])
      id <- tr$id[cell]
      got <- !is.na(id)
      out[[paste0(nm, "_pop")]][i[got]] <- tr$pop[as.character(id[got])]
      out[[paste0(nm, "_km2")]][i[got]] <- tr$cells[as.character(id[got])]
      out$settlement_window_edge[i[got]] <- out$settlement_window_edge[i[got]] |
        id[got] %in% tr$edge

      if (!is.null(nearest) && nm == nearest) {
        pc <- which(!is.na(tr$id))
        if (length(pc) > 0) {
          cxy <- terra::xyFromCell(s, pc)
          cll <- sf::sf_project(crs, "OGC:CRS84", cxy)
          for (j in seq_along(i)) {
            d <- haversine_m(lon[i[j]], lat[i[j]], cll[, 1], cll[, 2])
            w <- which.min(d)
            nid <- tr$id[pc[w]]
            # Inside a patch counts as distance zero, not the distance to its
            # own cell centre.
            out[[paste0(nearest, "_dist_km")]][i[j]] <- if (got[j]) 0 else d[w] / 1000
            out[[paste0(nearest, "_nearest_pop")]][i[j]] <- tr$pop[as.character(nid)]
            if (nid %in% tr$edge) out$settlement_window_edge[i[j]] <- TRUE
          }
        }
      }
    }
  }
  tibble::as_tibble(out)
}
