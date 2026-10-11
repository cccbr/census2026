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

#' Draft B: the tower's own contiguous settlement first, then its size
#'
#' Place measures only. Built around the question "what sort of place are
#' these bells in?", in four steps:
#'   1. Historic city cores: towers inside an urban centre with many other
#'      towers' bells close by (th$core_other_bells or more within 1 km), plus
#'      any tower on the curated special list (Q-022) as a backstop. Bands
#'      there are often shared, so a tower may have no band of its own.
#'   2. Other towers inside an urban centre, traced as a contiguous built-up
#'      area on the Degree of Urbanisation grid (R/contiguity.R). In a
#'      conurbation (centre of at least th$conurbation_pop people): "Inner
#'      city" where the local density reaches th$inner_density, otherwise
#'      "Suburban". In a smaller centre: "City or large town".
#'   3. Other towers by the people within 1 km: "Town" from th$town_pop_1km,
#'      "Village" from th$village_pop_1km, otherwise "Small village or hamlet".
#'
#' Bells enter step 1 only as OTHER towers' bells. A tower's own bells are
#' excluded, because counting them would tie the class to its own ring size
#' (D-028): bells within 1 km including the tower's own correlate about 0.9
#' with its ring size; other towers' bells about 0.2.
#'
#' @param centre_pop Population of the urban centre the tower is in (NA if
#'   none).
#' @param inner_d Local density used for the inner-city line.
#' @param pop1k People within 1 km.
#' @param other_bells Bells within 1 km at OTHER frame towers.
#' @param listed Logical: on the special list as a society or city-core tower.
#' @param th Named list: core_other_bells, conurbation_pop, inner_density,
#'   town_pop_1km, village_pop_1km.
#' @param levels Factor levels for the result.
classify_settlement_b <- function(centre_pop, inner_d, pop1k, other_bells, listed, th, levels) {
  in_centre <- !is.na(centre_pop)
  conurb <- in_centre & centre_pop >= th$conurbation_pop
  core <- listed | (in_centre & other_bells >= th$core_other_bells)
  type <- dplyr::case_when(
    core                                  ~ "Historic city core",
    conurb & inner_d >= th$inner_density  ~ "Inner city",
    conurb                                ~ "Suburban",
    in_centre                             ~ "City or large town",
    pop1k >= th$town_pop_1km              ~ "Town",
    pop1k >= th$village_pop_1km           ~ "Village",
    TRUE                                  ~ "Small village or hamlet"
  )
  factor(type, levels = levels)
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
