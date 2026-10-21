# Upload edits made to data/*.csv back to the private Google Sheet.
#
# Compares each local CSV with the live sheet and writes only the cells that
# differ, so formatting and untouched cells are left alone. Rows must match one
# to one: add or delete rows in the sheet itself, then fetch.
#
# Usage: Rscript R/push_data.R          # dry run: list the changes
#        Rscript R/push_data.R --apply  # write them to the sheet

source("R/fetch_data.R")

push_cv_data <- function(apply = FALSE, dir = "data") {
  sheet_id <- Sys.getenv("CV_SHEET_ID")
  email <- Sys.getenv("CV_EMAIL")
  if (sheet_id == "") stop("CV_SHEET_ID is not set. See .Renviron.example.")
  googlesheets4::gs4_auth(email = if (email == "") TRUE else email)

  n <- 0
  for (tab in tabs) {
    file <- file.path(dir, paste0(tab, ".csv"))
    if (!file.exists(file)) next
    local <- readr::read_csv(file, col_types = readr::cols(.default = "c"))
    remote <- googlesheets4::read_sheet(sheet_id, sheet = tab, skip = 1, col_types = "c")
    if (!identical(names(local), names(remote)) || nrow(local) != nrow(remote)) {
      stop(tab, ": columns or row count differ from the sheet. Change rows in the sheet, then fetch.")
    }
    for (j in seq_along(local)) {
      a <- local[[j]]; b <- remote[[j]]
      for (i in which(xor(is.na(a), is.na(b)) | (!is.na(a) & !is.na(b) & a != b))) {
        # +2: the sheet has a note row and a header row above the data
        cell <- paste0(cellranger::num_to_letter(j), i + 2)
        message(sprintf("%s!%s [%s]\n  - %s\n  + %s", tab, cell, names(local)[j], b[i], a[i]))
        n <- n + 1
        if (apply) {
          # readr::type_convert keeps numbers and TRUE/FALSE typed in the sheet
          value <- readr::type_convert(data.frame(x = a[i]), col_types = readr::cols(), guess_integer = TRUE)
          googlesheets4::range_write(sheet_id, value, sheet = tab, range = cell,
                                     col_names = FALSE, reformat = FALSE)
        }
      }
    }
  }
  message(n, " cell(s) differ", if (n && !apply) ". Run with --apply to write them." else ".")
  invisible(n)
}

if (sys.nframe() == 0) push_cv_data(apply = "--apply" %in% commandArgs(TRUE))
