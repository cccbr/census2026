# settlement.R ----------------------------------------------------------------
#
# Functions behind the settlement analysis chapters (analysis/): the
# one-sided model of density given ring size, and the place classification.
#
# CONTRACT: as for everything in R/, these functions take explicit inputs and
# return values. They do not read or write files. The choices they need
# (thresholds, which measure) are passed in by the caller, so the provisional
# values live in one visible place: analysis/_common.R.

#' One-sided ("stochastic frontier") model of log density given ring class
#'
#'   y = a[ring class] + v + u
#'   v ~ Normal(0, sv)     ordinary noise, either direction
#'   u ~ |Normal(0, su)|   growth since the bells were set: never negative
#'
#' Fitted by maximum likelihood (Aigner, Lovell & Schmidt 1977). The normal /
#' half-normal form is the standard first choice.
#'
#' @param y Numeric response (log10 density).
#' @param X Model matrix of ring-class indicators, no intercept.
#' @return list(a, a_se, sv, su, converged)
fit_sfa <- function(y, X) {
  k <- ncol(X)
  nll <- function(p) {
    a  <- p[1:k]; sv <- exp(p[k + 1]); su <- exp(p[k + 2])
    e  <- y - X %*% a
    s  <- sqrt(sv^2 + su^2); lam <- su / sv
    -sum(log(2) - log(s) + stats::dnorm(e / s, log = TRUE) +
           stats::pnorm(e * lam / s, log.p = TRUE))
  }
  start <- c(apply(X, 2, \(col) stats::quantile(y[col == 1], 0.25)), log(0.2), log(0.3))
  opt <- stats::optim(start, nll, method = "BFGS", hessian = TRUE)
  se  <- sqrt(diag(solve(opt$hessian)))
  list(a = opt$par[1:k], a_se = se[1:k],
       sv = exp(opt$par[k + 1]), su = exp(opt$par[k + 2]),
       converged = opt$convergence == 0)
}

#' Expected one-sided term for each unit given its residual
#'
#' Jondrow, Lovell, Materov & Schmidt (1982).
jlms_u <- function(e, sv, su) {
  s2  <- sv^2 + su^2
  mus <- e * su^2 / s2
  ss  <- su * sv / sqrt(s2)
  as.numeric(mus + ss * stats::dnorm(mus / ss) / stats::pnorm(mus / ss))
}

#' Draft A: village / town / city crossed with open or built-up region
#'
#' Place measures only, never ring size (Mark, 2026-10-10), so the class can be
#' crossed with ring size. Superseded as the working draft by Draft B (see
#' classify_settlement_b, 2026-10-11), but kept so the two can be compared.
#'
#' @param d Local density (people per km2 of land).
#' @param pop2,pop5 People within 2 km and 5 km.
#' @param region Regional density (people per km2 of land).
#' @param society Logical: on the special list as a society or city-core tower.
#' @param th Named list: town_density, town_pop, city_density, city_pop,
#'   region_density.
#' @param levels Factor levels for the result.
classify_settlement_a <- function(d, pop2, pop5, region, society, th, levels) {
  level <- dplyr::case_when(
    d >= th$city_density & pop5 >= th$city_pop ~ "city",
    d >= th$town_density & pop2 >= th$town_pop ~ "town",
    TRUE                                       ~ "village"
  )
  built <- region >= th$region_density
  type <- dplyr::case_when(
    society                     ~ "Society or city-core tower",
    level == "village" & !built ~ "Village",
    level == "village"          ~ "Village in a built-up region",
    level == "town"    & !built ~ "Town",
    level == "town"             ~ "Town in a built-up region",
    !built                      ~ "City or large town",
    TRUE                        ~ "City or large town in a conurbation"
  )
  factor(type, levels = levels)
}

#' Draft B: the tower's own contiguous settlement first, then its density
#'
#' Place measures only (D-028). Built around the question "what sort of
#' place are these bells in?" (D-036):
#'   1. Outside an urban centre (a contiguous built-up area on the Degree of
#'      Urbanisation grid, R/contiguity.R): "Town" from th$town_density,
#'      "Village" from th$village_density, otherwise "Small village or hamlet".
#'   2. Inside one, a tower is CENTRAL if either holds:
#'        - nres_ratio is at least th$centre_nres_ratio: the non-residential
#'          share of the buildings around the church, divided by the same
#'          share for its whole urban centre. A centre is where its town's
#'          shops and offices are, which population density cannot show,
#'          because town centres are short of residents;
#'        - there are th$old_centre_towers or more frame towers within 1 km,
#'          the tower itself included (an old centre).
#'      If that leaves a settlement with no central tower at all, its densest
#'      eligible tower is central, so every settlement has a centre.
#'      Every other tower in an urban centre is a SUBURB.
#'   3. The type names the settlement and the position: "Conurbation: centre"
#'      or "Conurbation: suburb" in an urban centre of th$conurbation_pop or
#'      more, "City or large town: centre" or "...: suburb" in a smaller one.
#'
#' Tower clusters are a separate flag, not a type: see tower_cluster().
#'
#' @param centre_key Identifier of the urban centre (NA if none).
#' @param centre_pop Its population (NA if none).
#' @param local_d The tower's local density (people per km2 of land): the
#'   town and village lines, and the fallback centre.
#' @param nres_ratio Non-residential share around the church divided by its
#'   urban centre's (NA where nothing is built, treated as not central).
#' @param towers_1km Frame towers within 1 km, the tower itself included.
#' @param eligible Logical: may this tower be a settlement's fallback centre?
#'   (Frame towers only, so that towers outside the frame never change the
#'   result for those in it.)
#' @param th Named list: conurbation_pop, centre_nres_ratio, old_centre_towers,
#'   town_density, village_density.
#' @param levels Factor levels for the result.
classify_settlement_b <- function(centre_key, centre_pop, local_d, nres_ratio,
                                  towers_1km, eligible, th, levels) {
  in_centre <- !is.na(centre_pop)
  eligible <- rep_len(eligible, length(centre_pop))
  conurb <- in_centre & centre_pop >= th$conurbation_pop
  central <- in_centre & (dplyr::coalesce(nres_ratio >= th$centre_nres_ratio, FALSE) |
                            towers_1km >= th$old_centre_towers)
  # Every settlement has a centre: where none qualifies, its densest eligible
  # tower is central.
  key <- ifelse(in_centre, centre_key, "")
  has_central <- as.logical(stats::ave(central & eligible, key, FUN = any))
  densest <- local_d == stats::ave(ifelse(eligible, local_d, -Inf), key, FUN = max)
  central <- central | (in_centre & eligible & densest & !has_central)
  type <- dplyr::case_when(
    conurb & central               ~ "Conurbation: centre",
    conurb                         ~ "Conurbation: suburb",
    in_centre & central            ~ "City or large town: centre",
    in_centre                      ~ "City or large town: suburb",
    local_d >= th$town_density     ~ "Town",
    local_d >= th$village_density  ~ "Village",
    TRUE                           ~ "Small village or hamlet"
  )
  factor(type, levels = levels)
}

#' Tower clusters: many towers within walking distance of each other
#'
#' A flag, not a type (D-036): th$cluster_towers or more frame towers within
#' 1 km, the tower itself included, or on the special list as a society tower
#' (Q-022) as a backstop. Counting towers, not bells, keeps ring size out
#' (D-028), and counting the tower itself means towers all within 1 km of
#' each other share one count, so a cluster is never split by its own rings.
tower_cluster <- function(towers_1km, listed, th) {
  listed | towers_1km >= th$cluster_towers
}

#' Turn each leaf of an rpart tree into a readable rule
#'
#' Density splits are on log10 scales, so they are converted back to people
#' per km2 of land, and repeated splits on one measure are merged into a
#' single range. Measure names are read with measure_label().
#'
#' @return Tibble: rule, towers, share (raw share of the second class).
leaf_rules <- function(tree) {
  leaves <- as.integer(rownames(tree$frame)[tree$frame$var == "<leaf>"])
  paths  <- rpart::path.rpart(tree, nodes = leaves, print.it = FALSE)
  nice_name <- function(v) {
    is_measure <- grepl("_[kr][0-9]+(m|km)$", v)
    ifelse(is_measure, measure_label(ifelse(is_measure, v, "k1km")), v)
  }
  num <- function(x) format(signif(x, 2), big.mark = ",", scientific = FALSE, trim = TRUE)
  describe <- function(p) {
    m <- regmatches(p, regexec("^([A-Za-z0-9_]+)\\s*(<|>=)\\s*(-?[0-9.e]+)$", p))
    m <- do.call(rbind, m[lengths(m) == 4])
    if (is.null(m)) return("all towers")
    logged <- grepl("^density_land_|^log_", m[, 2])
    val <- ifelse(logged, 10^as.numeric(m[, 4]), as.numeric(m[, 4]))
    parts <- tibble::tibble(var = m[, 2], op = m[, 3], val = val, logged = logged) |>
      dplyr::summarise(lo = suppressWarnings(max(val[op == ">="])),
                       hi = suppressWarnings(min(val[op == "<"])),
                       logged = logged[1], .by = "var")
    fmt_v <- function(x, lg) if (lg) num(x) else as.character(round(x, 2))
    purrr::pmap_chr(parts, \(var, lo, hi, logged) {
      paste0(nice_name(var), " ",
             if (is.finite(lo) && is.finite(hi)) paste0(fmt_v(lo, logged), " to ", fmt_v(hi, logged))
             else if (is.finite(lo)) paste0(fmt_v(lo, logged), " or more")
             else paste0("under ", fmt_v(hi, logged)))
    }) |> paste(collapse = "; ")
  }
  fr <- tree$frame[as.character(leaves), ]
  tibble::tibble(
    rule   = vapply(paths, \(p) describe(p[-1]), ""),
    towers = fr$n,
    # Raw share of the second class in the leaf. Not yval2[, 5], which is
    # adjusted by the tree's priors when they are not the observed shares.
    share  = fr$yval2[, 3] / (fr$yval2[, 2] + fr$yval2[, 3])
  ) |> dplyr::arrange(.data$share)
}
