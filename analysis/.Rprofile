# Quarto runs R from this folder, not from the repo root, so the root
# .Rprofile never runs and renv is never activated. Without this file, R
# falls back to the user library, where knitr and rmarkdown are missing.
# Point renv at the project root explicitly.
Sys.setenv(RENV_PROJECT = normalizePath(".."))
source(file.path("..", "renv", "activate.R"))
