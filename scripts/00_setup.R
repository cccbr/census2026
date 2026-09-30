# 00_setup.R ------------------------------------------------------------------
#
# Source this at the top of every script and at the top of every .qmd.
# It loads packages and sources everything in R/. It does nothing else —
# no data loading, no side effects.

library(tidyverse)
library(fs)
library(here)
library(arrow)

# Sourced, not attached: R/ holds functions only.
purrr::walk(fs::dir_ls(here::here("R"), glob = "*.R"), source)

# Project-wide constants ------------------------------------------------------

# Dove's Guide is licensed CC BY-SA 4.0. Any redistribution of a substantial
# extract — including the tower array embedded in the questionnaire — must
# carry this attribution.
DOVE_ATTRIBUTION <- paste(
  "Tower data from Dove's Guide for Church Bell Ringers",
  "(https://dove.cccbr.org.uk), (c) the Central Council of Church Bell Ringers,",
  "licensed CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/).",
  "Modified: filtered to ringable rings and reformatted."
)
