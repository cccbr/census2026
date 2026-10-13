# config/choices.R ------------------------------------------------------------
#
# The provisional methodological choices the pipeline and the analysis share:
# which measures are used, the classification thresholds, and the category
# names. Sourced by scripts/00_setup.R.
#
# Starting points for the analytical team to calibrate. None is a decision
# unless the decision register says so. Each change here is a methodological
# choice: cite the D- or Q- entry it rests on, next to the line, in the same
# commit. A threshold buried in a script is how an indefensible number reaches
# a committee paper.
#
# After changing anything here, re-run scripts/B05_build_tower_classes.R and
# re-render the analysis chapters one by one (Quarto's freeze does not notice
# changes to this file).

# Q-020 OPEN: bells at a tower with two frame rings. On dove_2026-09-19 this
# affects two towers only: Gresford (8 + 6) and Rugby (8 + 5). "max" counts the
# larger ring. "sum" counts every bell.
MULTI_RING_BELLS <- "max"

# Density measures, all people per km2 of LAND so the sea does not count as
# empty.
#   DENSITY_VAR: used to study ring size against density (2 km kernel).
#   LOCAL_VAR:   the walkable population: people per km2 of LAND in the
#                250 m kernel (half its weight within about 600 m). The town
#                and village lines (D-037). It also fits band outcomes best
#                in the Gloucester & Bristol register (chapter 2).
#   NRES_VAR:    the non-residential share of the built-up surface in the
#                500 m kernel: shops, offices and the like. Finds centres
#                where retail centres are not mapped (abroad), and is kept as
#                a descriptive measure (D-036).
#   TIGHT_VAR:   the 250 m kernel, as named in the side-quest chapter on what
#                the bells remember.
#   beyond_walk: an indicator, not a classifier (D-037): people per km2 of
#                land within reach by car but beyond walking distance, the
#                2 km kernel with the 250 m kernel's people and land taken
#                out. Sorts the draw within strata.
#   Densities, not counts, so the lines compare with the Degree of
#   Urbanisation's 300 and 1,500 per km2 (Mark, 2026-10-11).
#   REGION_VAR:  the wider region (8 km kernel).
DENSITY_VAR   <- "density_land_k2km"
LOCAL_VAR     <- "density_land_k250m"
NRES_VAR      <- "nres_share_k500m"
TIGHT_VAR     <- "density_land_k250m"
REGION_VAR    <- "density_land_k8km"
DRAFT_A_LOCAL_VAR <- "density_land_r1km"   # Draft A as it was, for comparison

# Ring-size classes. Rings of 3 are outside the frame (4+ bells) but are used
# in the structure analysis, because they say what sort of place has a small
# ring.
RING_BREAKS <- c(2.5, 3.5, 5.5, 7.5, 9.5, Inf)
RING_LABELS <- c("3", "4-5", "6-7", "8-9", "10+")

# Draft A thresholds (superseded as the working draft; kept for comparison).
#   town: local density >= 300 per km2, and >= 5,000 people within 2 km
#   city or large town: local density >= 1,500, and >= 50,000 within 5 km
#   region: built-up at or above 1,000 per km2 in the 8 km kernel
DRAFT_A <- list(town_density = 300, town_pop = 5000,
                city_density = 1500, city_pop = 50000,
                region_density = 1000)

# Draft C thresholds: the working draft (D-037). See R/settlement.R.
#   conurbation_pop: an urban centre this size or larger is a conurbation.
#     Set in a gap in UK centre sizes (Nottingham 636k | Leicester 513k), so
#     small data changes cannot move a city across it; keeps Bristol in.
#   centre_retail_tier, centre_retail_m: inside an urban centre, a tower is
#     central if it is within 250 m (about three minutes' walk: on or by the
#     high street) of a retail centre of tier 4 or larger: a district centre,
#     town centre or market town, major town centre or regional centre
#     (scripts/B04_build_retail_context.R). District centres count because the
#     classification ranks centres against bigger neighbours: Warwick and
#     Dudley are district centres.
#   centre_nres_ratio: where retail centres are not mapped (abroad), a tower
#     is central instead if the non-residential share of the buildings
#     around it is at least its urban centre's own share (D-036).
#   old_centre_towers: inside an urban centre, a tower with this many frame
#     towers within 1 km (itself included) is central whatever is round it.
#   cluster_towers: the tower-cluster flag. 5 or more frame towers within
#     1 km, itself included: towers close enough for one band to ring several
#     in a morning (Mark, 2026-10-11).
#   town_density: a town outside an urban centre, people per km2 of land in
#     the 250 m kernel. 600 is the best match to 1988's share of towns.
#   village_density: below this, a small village or hamlet. 200, below the
#     Degree of Urbanisation's cluster line (300), so that "village" is not
#     one monolithic class and the larger type keeps the plainer name (Mark).
DRAFT_C <- list(conurbation_pop = 575000, centre_retail_tier = 4, centre_retail_m = 250,
                centre_nres_ratio = 1, old_centre_towers = 3,
                cluster_towers = 5, town_density = 600, village_density = 200)

# Special-list categories treated as "society or city-core" towers (Q-022).
SOCIETY_CATEGORIES <- c("society_steeple_keeper", "city_of_london_other",
                        "central_london_major")

# ---- settlement type names ----------------------------------------------------
TYPE_LEVELS <- c("Small village or hamlet", "Village", "Town",
                 "City or large town: suburb", "City or large town: centre",
                 "Conurbation: suburb", "Conurbation: centre")
TYPE_LEVELS_A <- c("Village", "Village in a built-up region",
                   "Town", "Town in a built-up region",
                   "City or large town", "City or large town in a conurbation",
                   "Society or city-core tower")

# ---- 1988 comparison ------------------------------------------------------------
# How Draft C's types map onto 1988's five. Tower clusters are mapped
# separately, to "Large City" (see type_1988).
crosswalk_1988 <- c(
  "Small village or hamlet"    = "Village",
  "Village"                    = "Village",
  "Town"                       = "Town",
  "City or large town: suburb" = "Suburban",
  "City or large town: centre" = "Large City",
  "Conurbation: suburb"        = "Suburban",
  "Conurbation: centre"        = "Inner City"
)
