# Download the CV data from a private Google Sheet into data/*.csv.
#
# Setup: copy .Renviron.example to .Renviron and set CV_SHEET_ID and CV_EMAIL.
# The first run opens a browser to log in to Google; the token is cached
# locally by gargle and never stored in this repo.
#
# Usage: Rscript R/fetch_data.R

tabs <- c("entries", "language_skills", "text_blocks", "contact_info")

fetch_cv_data <- function(out_dir = "data") {
  sheet_id <- Sys.getenv("CV_SHEET_ID")
  email <- Sys.getenv("CV_EMAIL")
  if (sheet_id == "") stop("CV_SHEET_ID is not set. See .Renviron.example.")

  googlesheets4::gs4_auth(email = if (email == "") TRUE else email)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  # Read every tab first, so a failure (e.g. a rate limit) leaves data/ untouched.
  # skip = 1: the first row of each tab is a human-readable note.
  data <- lapply(setNames(tabs, tabs), function(tab) {
    googlesheets4::read_sheet(sheet_id, sheet = tab, skip = 1, col_types = "c")
  })

  # Only rewrite files whose content changed, so `make` can tell nothing happened.
  for (tab in tabs) {
    dest <- file.path(out_dir, paste0(tab, ".csv"))
    tmp <- tempfile(fileext = ".csv")
    readr::write_csv(data[[tab]], tmp)
    if (file.exists(dest) && tools::md5sum(dest) == tools::md5sum(tmp)) {
      message("Unchanged: ", dest)
    } else {
      file.copy(tmp, dest, overwrite = TRUE)
      message("Updated:   ", dest, " (", nrow(data[[tab]]), " rows)")
    }
  }
  invisible(out_dir)
}

if (sys.nframe() == 0) fetch_cv_data()
