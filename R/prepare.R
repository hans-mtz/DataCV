# Runs before every render (see _quarto.yml). Writes cv/_author-<version>.yml
# (gitignored) with name, position and contact links built from the data, so
# no personal details are typed in the .qmd files.
#
# Name and address come from .Renviron (CV_FIRSTNAME, CV_LASTNAME, CV_ADDRESS,
# CV_CITY); the headline per version comes from a text block with loc = "position".
# The academic CV prints the full address on its own line; the Typst CVs put the
# city (CV_CITY, or CV_ADDRESS if unset) in the contact line with a location icon.

source("R/cv_helpers.R")
cv_load_env()
d <- cv_load()

# Font Awesome / local icon for each contact type in contact_info.csv
icon_for <- c(email = "fa envelope", linkedin = "fa brands linkedin",
              github = "fa brands github", twitter = "fa brands x-twitter",
              orcid = "fa brands orcid", website = "../assets/icon/bi-house-fill.svg")

# contact_info stores "[text](url)"; split into text and url
m <- regmatches(d$contact$contact, regexec("^\\[(.*)\\]\\((.*)\\)$", d$contact$contact))
contacts <- lapply(seq_along(m), function(i) {
  list(icon = unname(icon_for[d$contact$loc[i]]),
       text = m[[i]][2], url = m[[i]][3], key = d$contact$loc[i])
})

env_or <- function(name, default) {
  v <- Sys.getenv(name)
  if (v == "") default else v
}

# Bibliography for citations in text blocks, if the data folder has one
bib <- file.path(cv_data_dir(), "references.bib")

address <- env_or("CV_ADDRESS", "")
city <- env_or("CV_CITY", address)

for (v in CV_VERSIONS) {
  pos <- cv_text(d, v, "position")
  cts <- lapply(contacts, function(x) x[c("icon", "text", "url")])
  inline <- v != "academic" && city != ""
  if (inline) cts <- c(list(list(icon = "fa location-dot", text = city, url = "")), cts)
  author <- list(
    firstname = env_or("CV_FIRSTNAME", "Your"),
    lastname = env_or("CV_LASTNAME", "Name"),
    address = if (inline) "" else address,
    position = if (is.na(pos)) "" else pos,
    contacts = cts
  )
  meta <- list(author = author)
  # only the academic CV cites; path relative to cv/ (must be inside the project)
  if (v == "academic" && file.exists(bib)) {
    meta$bibliography <- paste0("../", sub(paste0("^", normalizePath("."), "/"), "", normalizePath(bib)))
  }
  yaml::write_yaml(meta, file.path("cv", paste0("_author-", v, ".yml")))
}
message("Wrote cv/_author-*.yml from ", cv_data_dir())
