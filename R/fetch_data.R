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

  for (tab in tabs) {
    # skip = 1: the first row of each tab is a human-readable note
    df <- googlesheets4::read_sheet(sheet_id, sheet = tab, skip = 1, col_types = "c")
    readr::write_csv(df, file.path(out_dir, paste0(tab, ".csv")))
    message("Wrote ", file.path(out_dir, paste0(tab, ".csv")), " (", nrow(df), " rows)")
  }
  invisible(out_dir)
}

if (sys.nframe() == 0) fetch_cv_data()
