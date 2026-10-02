# Helpers that turn the CV tables (entries, skills, text_blocks, contact_info)
# into Typst or LaTeX for the three CV versions.
#
# Entries are shown in a CV when in_resume is TRUE and `versions` contains the
# CV's version (or "all"). Within a section they are sorted by `priority`
# (ascending, blanks last), then by sheet order.

CV_VERSIONS <- c("academic", "industry", "teaching")

# Sections rendered as publications (title + venue + coauthors) vs positions
PUB_SECTIONS <- c("academic_articles", "working_papers", "reports")

# ---- Paths and loading -------------------------------------------------------

cv_root <- function(start = getwd()) {
  p <- normalizePath(start)
  while (!file.exists(file.path(p, "_quarto.yml"))) {
    parent <- dirname(p)
    if (parent == p) stop("Could not find the project root (_quarto.yml).")
    p <- parent
  }
  p
}

cv_load_env <- function() {
  f <- file.path(cv_root(), ".Renviron")
  if (file.exists(f)) readRenviron(f)
}

# Real data in data/ if present, otherwise the fake example data.
cv_data_dir <- function() {
  cv_load_env()
  d <- Sys.getenv("CV_DATA_DIR")
  if (d != "") return(d)
  root <- cv_root()
  if (file.exists(file.path(root, "data", "entries.csv"))) file.path(root, "data")
  else file.path(root, "data", "example")
}

cv_load <- function(dir = cv_data_dir()) {
  rd <- function(f) {
    readr::read_csv(file.path(dir, f), col_types = readr::cols(.default = "c"),
                    show_col_types = FALSE)
  }
  entries <- rd("entries.csv")
  entries$.row <- seq_len(nrow(entries))
  entries$in_resume <- toupper(trimws(entries$in_resume)) %in% "TRUE"
  entries$priority <- suppressWarnings(as.numeric(entries$priority))
  list(entries = entries, skills = rd("language_skills.csv"),
       text = rd("text_blocks.csv"), contact = rd("contact_info.csv"))
}

# "academic; industry", "teaching:academic", "all" -> character vector
parse_versions <- function(x) {
  v <- lapply(strsplit(tolower(ifelse(is.na(x), "", x)), "[;:,]"), trimws)
  lapply(v, function(z) z[z != ""])
}

cv_entries <- function(d, version, sections) {
  stopifnot(version %in% CV_VERSIONS)
  e <- d$entries
  vs <- parse_versions(e$versions)
  unknown <- setdiff(unlist(vs), c(CV_VERSIONS, "all"))
  if (length(unknown)) {
    warning("Unknown values in `versions`: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  keep <- e$in_resume & e$section %in% sections &
    vapply(vs, function(z) any(z %in% c(version, "all")), logical(1))
  e <- e[keep, , drop = FALSE]
  e[order(is.na(e$priority), e$priority, e$.row), , drop = FALSE]
}

# Text block for a version. Version-specific rows come before `all` rows.
cv_text <- function(d, version, loc) {
  t <- d$text[d$text$loc == loc & !is.na(d$text$text) &
                d$text$version %in% c(version, "all"), , drop = FALSE]
  if (!nrow(t)) return(NA_character_)
  t <- t[order(t$version == "all"), ]
  t$text[1]
}

# `type` column is optional: "language" rows are languages, anything else is
# software. Software is sorted by numeric level; languages keep sheet order and
# show their level as text, e.g. "Spanish (native)".
cv_skills <- function(d, type = "software") {
  s <- d$skills
  is_lang <- if ("type" %in% names(s)) tolower(trimws(s$type)) %in% "language" else rep(FALSE, nrow(s))
  s <- s[if (type == "language") is_lang else !is_lang, , drop = FALSE]
  if (!nrow(s)) return(NA_character_)
  if (type == "language") {
    return(paste(ifelse(blank(s$level), s$skill, sprintf("%s (%s)", s$skill, s$level)), collapse = ", "))
  }
  paste(s$skill[order(-as.numeric(s$level))], collapse = ", ")
}

# ---- Inline formatting -------------------------------------------------------

esc_typst <- function(x) {
  x <- gsub("([\\\\#$@<>*_`\\[\\]~])", "\\\\\\1", x, perl = TRUE)
  gsub("//", "\\\\//", x)
}

esc_latex <- function(x) {
  map <- c("\\" = "\\textbackslash{}", "&" = "\\&", "%" = "\\%", "$" = "\\$",
           "#" = "\\#", "_" = "\\_", "{" = "\\{", "}" = "\\}",
           "~" = "\\textasciitilde{}", "^" = "\\textasciicircum{}")
  chars <- strsplit(x, "")[[1]]
  hit <- chars %in% names(map)
  chars[hit] <- map[chars[hit]]
  paste(chars, collapse = "")
}

# Convert light Markdown ([text](url), **bold**, *italic*) to Typst or LaTeX.
md_inline <- function(x, engine) {
  if (is.null(x) || is.na(x) || x == "") return("")
  esc <- if (engine == "typst") esc_typst else esc_latex
  pats <- c(link = "\\[([^\\]]+)\\]\\(([^)]+)\\)", bold = "\\*\\*(.+?)\\*\\*",
            ital = "\\*(.+?)\\*")
  pos <- vapply(pats, function(p) regexpr(p, x, perl = TRUE)[1], numeric(1))
  if (all(pos == -1)) return(esc(x))
  kind <- names(which.min(replace(pos, pos == -1, Inf)))
  m <- regmatches(x, regexec(pats[[kind]], x, perl = TRUE))[[1]]
  start <- pos[[kind]]
  before <- substr(x, 1, start - 1)
  after <- substr(x, start + nchar(m[1]), nchar(x))
  inner <- md_inline(m[2], engine)
  out <- if (engine == "typst") {
    switch(kind,
      link = sprintf('#link("%s")[%s]', gsub('(["\\\\])', "\\\\\\1", m[3]), inner),
      bold = sprintf("#strong[%s]", inner),
      ital = sprintf("#emph[%s]", inner))
  } else {
    switch(kind,
      link = sprintf("\\href{%s}{%s}", gsub("([%#])", "\\\\\\1", m[3]), inner),
      bold = sprintf("\\textbf{%s}", inner),
      ital = sprintf("\\emph{%s}", inner))
  }
  paste0(esc(before), out, md_inline(after, engine))
}

blank <- function(x) is.na(x) | trimws(x) == ""

cv_date <- function(start, end) {
  if (blank(start) && blank(end)) return("")
  if (blank(start)) return(end)
  if (blank(end)) return(paste(start, "– Present"))
  if (start == end) return(start)
  paste(start, "–", end)
}

# "with A. Author" -> "(with A. Author)" for LaTeX publication lines
wrap_with <- function(x) if (!blank(x) && grepl("^with\\b", x)) paste0("(", x, ")") else x

details_of <- function(row) {
  v <- unlist(row[paste0("description_", 1:6)], use.names = FALSE)
  v[!blank(v)]
}

# ---- Typst -------------------------------------------------------------------

typst_entry <- function(title, location, date, description, details = character(),
                        as_list = TRUE) {
  m <- function(x) paste0("[", md_inline(x, "typst"), "]")
  out <- sprintf("#resume-entry(\n  title: %s,\n  location: %s,\n  date: %s,\n  description: %s,\n)",
                 m(title), m(location), m(date), m(description))
  if (length(details)) {
    items <- vapply(details, md_inline, "", engine = "typst", USE.NAMES = FALSE)
    body <- if (as_list) paste0("- ", items, collapse = "\n") else paste(items, collapse = "\n\n")
    out <- paste0(out, "\n#resume-item[\n", body, "\n]")
  }
  out
}

typst_section <- function(e, details = FALSE) {
  vapply(seq_len(nrow(e)), function(i) {
    r <- e[i, ]
    d <- if (details || !(r$section %in% PUB_SECTIONS)) details_of(r) else character()
    if (r$section %in% PUB_SECTIONS) {
      title <- if (!blank(r$url)) sprintf("[%s](%s)", r$title, r$url) else r$title
      venue <- if (!blank(r$institution)) paste0("*", r$institution, "*") else ""
      typst_entry(title, venue, cv_date(NA, r$end), r$loc, d, as_list = FALSE)
    } else {
      typst_entry(r$title, r$loc, cv_date(r$start, r$end), r$institution, d)
    }
  }, character(1))
}

# ---- LaTeX -------------------------------------------------------------------

latex_bullets <- function(details) {
  if (!length(details)) return(character())
  c("\\begin{itemize}",
    paste0("  \\item ", vapply(details, md_inline, "", engine = "latex")),
    "\\end{itemize}")
}

latex_section <- function(e, details = FALSE) {
  if (!nrow(e)) return(character())
  m <- function(x) md_inline(x, "latex")
  if (all(e$section %in% PUB_SECTIONS)) {
    return(unlist(lapply(seq_len(nrow(e)), function(i) {
      r <- e[i, ]
      title <- if (!blank(r$url)) sprintf("[%s](%s)", r$title, r$url) else r$title
      rest <- paste(c(if (!blank(r$loc)) m(wrap_with(r$loc)),
                      if (!blank(r$institution)) paste0("\\emph{", m(r$institution), "}"),
                      if (!blank(r$end)) m(r$end)), collapse = ", ")
      out <- sprintf("\\pub{%s}{%s.}", m(title), rest)
      d <- details_of(r)
      if (details && length(d)) out <- c(out, sprintf("\\pubabs{%s}", m(paste(d, collapse = " "))))
      out
    })))
  }
  if (all(e$section == "education")) {
    return(unlist(lapply(seq_len(nrow(e)), function(i) {
      r <- e[i, ]
      c(sprintf("\\textbf{%s}%s \\hfill \\emph{%s}", m(r$title),
                if (!blank(r$institution)) paste0(", ", m(r$institution)) else "",
                m(cv_date(r$start, r$end))),
        latex_bullets(details_of(r)), "")
    })))
  }
  # Positions: group rows of the same institution under one heading
  unlist(lapply(unique(e$institution), function(inst) {
    g <- e[e$institution %in% inst, ]
    loc <- g$loc[!blank(g$loc)][1]
    head <- sprintf("\\textbf{%s} \\hfill %s\\\\", m(inst), if (is.na(loc)) "" else m(loc))
    rows <- unlist(lapply(seq_len(nrow(g)), function(i) {
      r <- g[i, ]
      c(sprintf("%s \\hfill \\emph{%s}%s", m(r$title), m(cv_date(r$start, r$end)),
                if (i < nrow(g) || length(details_of(r))) "\\\\" else ""),
        latex_bullets(details_of(r)))
    }))
    c(head, rows, "")
  }))
}

latex_heading <- function(title) {
  sprintf("\\section{{\\Large %s}%s}", substr(toupper(title), 1, 1), substring(toupper(title), 2))
}

# Centered header block for the academic version
latex_header <- function(author, contacts = NULL) {
  m <- function(x) md_inline(x, "latex")
  # Display order and Font Awesome 5 icon for each contact type, matched on the icon name
  icons <- c(envelope = "\\faEnvelope", house = "\\faGlobe", github = "\\faGithub",
             linkedin = "\\faLinkedin", twitter = "\\faTwitter")
  keep <- if (is.null(contacts)) names(icons) else intersect(names(icons), contacts)
  links <- character()
  for (k in keep) {
    for (i in Filter(function(i) grepl(k, i$icon), author$contacts)) {
      links <- c(links, sprintf("%s\\,\\href{%s}{%s}", icons[[k]],
                                gsub("([%#])", "\\\\\\1", i$url), esc_latex(i$text)))
    }
  }
  c(sprintf("\\centerline{\\huge \\bf %s %s}", m(author$firstname), m(author$lastname)),
    "\\vspace{1mm}",
    sprintf("\\centerline{\\Large \\bf %s}", m(author$position)),
    "\\vspace{1mm}", "\\hrule", "\\vspace{1mm}",
    if (!blank(author$address)) sprintf("\\centerline{%s}", m(author$address)),
    sprintf("\\centerline{\\small %s}", paste(links, collapse = " \\quad ")),
    "\\vspace{1mm}", "\\hrule")
}

# ---- Emit --------------------------------------------------------------------

# Write lines as a raw block for Pandoc (use in a chunk with results: asis)
cv_emit <- function(lines, engine) {
  if (!length(lines)) return(invisible())
  cat(sprintf("\n```{=%s}\n%s\n```\n", engine, paste(lines, collapse = "\n")))
  invisible()
}

cv_heading <- function(title, engine) {
  if (engine == "typst") cat("\n\n## ", title, "\n\n", sep = "")
  else cv_emit(latex_heading(title), "latex")
}

# One call per section: filter, sort, format, print. The heading (and an
# optional intro text block, `aside`) is only printed when there are entries.
cv_print_section <- function(d, version, sections, engine, title = NULL,
                             details = FALSE, aside = NULL) {
  e <- cv_entries(d, version, sections)
  if (!nrow(e)) return(invisible())
  if (!is.null(title)) cv_heading(title, engine)
  if (!is.null(aside)) cv_print_text(d, version, aside)
  lines <- if (engine == "typst") typst_section(e, details) else latex_section(e, details)
  cv_emit(lines, engine)
}

cv_print_skills <- function(d, engine, title = "Skills") {
  sw <- cv_skills(d, "software")
  lang <- cv_skills(d, "language")
  if (is.na(sw) && is.na(lang)) return(invisible())
  cv_heading(title, engine)
  if (!is.na(sw)) cat("\n**Software:** ", sw, "\n", sep = "")
  if (!is.na(lang)) cat("\n**Languages:** ", lang, "\n", sep = "")
}

# Free text (intro, asides) is plain Markdown that Pandoc converts itself.
# Tries each loc in order, e.g. c("intro_industry", "intro").
cv_print_text <- function(d, version, locs) {
  for (loc in locs) {
    t <- cv_text(d, version, loc)
    if (!is.na(t)) { cat("\n", t, "\n", sep = ""); return(invisible()) }
  }
}
