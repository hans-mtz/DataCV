# Helpers that turn the CV tables (entries, skills, text_blocks, contact_info)
# into Typst or LaTeX for the three CV versions.
#
# Entries are shown in a CV when in_resume is TRUE and `versions` contains the
# CV's version (or "all"). Within a section they are sorted by `priority`
# (ascending, blanks last), then by sheet order.

CV_VERSIONS <- c("academic", "industry", "teaching")

# Sections rendered as publications (title + venue + coauthors) vs positions
PUB_SECTIONS <- c("academic_articles", "working_papers", "reports", "work_in_progress", "conferences")

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
  for (col in c("tag", "url")) if (!col %in% names(entries)) entries[[col]] <- NA_character_
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

# Reference person: title = name, description_1 = role, institution = affiliation,
# url = email (with or without "mailto:")
ref_email <- function(r) if (blank(r$url)) NA_character_ else sub("^mailto:", "", r$url)

# A bullet can be limited to some CVs with a prefix: "[[academic;teaching]] text"
# shows it only there; "[[!industry]] text" hides it from the industry CV.
# Bullets without a prefix appear in every version.
tag_applies <- function(tag, version) {
  tok <- parse_versions(tag)[[1]]
  neg <- grepl("^!", tok)
  if (any(neg)) return(!(version %in% sub("^!", "", tok[neg])))
  any(tok %in% c(version, "all"))
}

details_of <- function(row, version = NULL) {
  v <- unlist(row[paste0("description_", 1:6)], use.names = FALSE)
  v <- v[!blank(v)]
  if (is.null(version) || !length(v)) return(v)
  pat <- "^\\s*\\[\\[([^]]*)\\]\\]\\s*"
  tag <- ifelse(grepl(pat, v), sub(paste0(pat, ".*"), "\\1", v), NA_character_)
  keep <- vapply(tag, function(t) is.na(t) || tag_applies(t, version), logical(1))
  sub(pat, "", v[keep])
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

typst_references <- function(e) {
  m <- function(x) md_inline(x, "typst")
  cell <- function(r) {
    email <- ref_email(r)
    parts <- c(sprintf("#strong[%s]", m(r$title)),
               if (!blank(r$description_1)) m(r$description_1),
               if (!blank(r$institution)) m(r$institution),
               if (!is.na(email)) sprintf('#link("mailto:%s")[%s]', email, esc_typst(email)))
    paste0("[", paste(parts, collapse = " \\\n"), "]")
  }
  paste0("#resume-item[\n#pad(top: 0.4em)[#grid(columns: (1fr, 1fr), row-gutter: 1em,\n",
         paste(vapply(seq_len(nrow(e)), function(i) cell(e[i, ]), ""), collapse = ",\n"),
         ",\n)]\n]")
}

typst_section <- function(e, details = FALSE, version = NULL) {
  if (all(e$section == "references")) return(typst_references(e))
  vapply(seq_len(nrow(e)), function(i) {
    r <- e[i, ]
    d <- if (details || !(r$section %in% PUB_SECTIONS)) details_of(r, version) else character()
    if (r$section %in% PUB_SECTIONS) {
      title <- if (!blank(r$url)) sprintf("[%s](%s)", r$title, r$url) else r$title
      venue <- if (!blank(r$institution)) paste0("*", r$institution, "*") else ""
      who <- paste(c(if (!blank(r$tag)) paste0("(", r$tag, ")"),
                     if (!blank(r$loc)) r$loc), collapse = " ")
      typst_entry(title, venue, cv_date(NA, r$end), who, d, as_list = FALSE)
    } else {
      typst_entry(r$title, r$loc, cv_date(r$start, r$end), r$institution, d)
    }
  }, character(1))
}

# ---- LaTeX -------------------------------------------------------------------

latex_bullets <- function(details) {
  if (!length(details)) return(character())
  # blank line ends the entry line; -\parskip cancels the gap before the list
  c("", "\\vspace{-\\parskip}", "\\begin{itemize}",
    paste0("  \\item ", vapply(details, md_inline, "", engine = "latex")),
    "\\end{itemize}")
}

latex_references <- function(e) {
  m <- function(x) md_inline(x, "latex")
  person <- function(r) {
    email <- ref_email(r)
    parts <- c(sprintf("\\textbf{%s}", m(r$title)),
               if (!blank(r$description_1)) m(r$description_1),
               if (!blank(r$institution)) m(r$institution),
               if (!is.na(email)) sprintf("\\href{mailto:%s}{%s}", gsub("([%#])", "\\\\\\1", email), esc_latex(email)))
    paste(parts, collapse = "\\\\\n")
  }
  box <- function(r) sprintf("\\begin{minipage}[t]{0.48\\textwidth}\n%s\n\\end{minipage}", person(r))
  unlist(lapply(seq(1, nrow(e), by = 2), function(i) {
    left <- box(e[i, ])
    right <- if (i < nrow(e)) paste0("\\hfill\n", box(e[i + 1, ]))
    c(paste0("\\noindent", left, right), "\\vspace{0.6em}", "")
  }))
}

latex_section <- function(e, details = FALSE, version = NULL) {
  if (!nrow(e)) return(character())
  if (all(e$section == "references")) return(latex_references(e))
  m <- function(x) md_inline(x, "latex")
  if (all(e$section %in% PUB_SECTIONS)) {
    return(unlist(lapply(seq_len(nrow(e)), function(i) {
      r <- e[i, ]
      title <- if (!blank(r$url)) sprintf("[%s](%s)", r$title, r$url) else r$title
      parts <- c(if (!blank(r$loc)) m(wrap_with(r$loc)),
                 if (!blank(r$institution)) paste0("\\emph{", m(r$institution), "}"),
                 if (!blank(r$end)) m(r$end))
      body <- if (length(parts)) paste0(sub("\\.$", "", paste(parts, collapse = ", ")), ".") else ""
      lead <- if (!blank(r$tag)) paste0("(", m(r$tag), ")")
      rest <- paste(c(lead, body[body != ""]), collapse = " ")
      # the title ends with a period unless it already ends with ? ! or .
      head <- paste0(m(title), if (grepl("[.?!]$", trimws(r$title))) "" else ".")
      out <- sprintf("\\pub{%s}{%s}", head, rest)
      d <- details_of(r, version)
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
        latex_bullets(details_of(r, version)), "")
    })))
  }
  # Positions: group rows of the same institution under one heading
  unlist(lapply(unique(e$institution), function(inst) {
    g <- e[e$institution %in% inst, ]
    loc <- g$loc[!blank(g$loc)][1]
    head <- sprintf("\\textbf{%s} \\hfill %s\\\\", m(inst), if (is.na(loc)) "" else m(loc))
    rows <- unlist(lapply(seq_len(nrow(g)), function(i) {
      r <- g[i, ]
      bullets <- details_of(r, version)
      c(sprintf("%s \\hfill \\emph{%s}%s", m(r$title), m(cv_date(r$start, r$end)),
                if (i < nrow(g) && !length(bullets)) "\\\\" else ""),
        latex_bullets(bullets))
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
  lines <- if (engine == "typst") typst_section(e, details, version) else latex_section(e, details, version)
  cv_emit(lines, engine)
}

# Research interests: text blocks `fields` (major fields), `subfields` (specializations)
# and `teaching_fields`, e.g. "Industrial Organization; Public Economics". Printed only
# if at least one is set for the version.
cv_print_fields <- function(d, version, engine, title = "Research Interests") {
  major <- cv_text(d, version, "fields")
  sub <- cv_text(d, version, "subfields")
  teach <- cv_text(d, version, "teaching_fields")
  if (is.na(major) && is.na(sub) && is.na(teach)) return(invisible())
  cv_heading(title, engine)
  if (!is.na(major)) cat("\n**Fields:** ", major, "\n", sep = "")
  if (!is.na(sub)) cat("\n**Subfields:** ", sub, "\n", sep = "")
  if (!is.na(teach)) cat("\n**Teaching:** ", teach, "\n", sep = "")
}

cv_print_skills <- function(d, engine, title = "Skills") {
  sw <- cv_skills(d, "software")
  lang <- cv_skills(d, "language")
  if (is.na(sw) && is.na(lang)) return(invisible())
  cv_heading(title, engine)
  if (!is.na(sw)) cat("\n**Software:** ", sw, "\n", sep = "")
  if (!is.na(lang)) cat("\n**Languages:** ", lang, "\n", sep = "")
}

# Abstracts for the end of the CV. Each entry's description_1..6 (after
# version filtering) become paragraphs under the entry's title, printed as
# Markdown so Pandoc resolves citations ([@key]) with the bibliography found by
# R/prepare.R (references.bib next to the CSVs). Single line breaks inside a cell
# become paragraph breaks. If anything is cited, cv_print_refs() prints the list.
.cv_state <- new.env()

cv_print_abstracts <- function(d, version, sections, engine, title = "Abstracts") {
  e <- cv_entries(d, version, sections)
  blocks <- lapply(seq_len(nrow(e)), function(i) {
    r <- e[i, ]
    paras <- details_of(r, version)
    if (!length(paras)) return(NULL)
    head <- paste0("**", r$title, "**", if (!blank(r$tag)) paste0(" (", r$tag, ")"))
    paste(c(head, gsub("\n+", "\n\n", paras)), collapse = "\n\n")
  })
  blocks <- Filter(Negate(is.null), blocks)
  if (!length(blocks)) return(invisible())
  cv_heading(title, engine)
  cat("\n", paste(blocks, collapse = "\n\n"), "\n", sep = "")
  if (any(grepl("@", unlist(blocks), fixed = TRUE))) .cv_state$cited <- TRUE
}

cv_print_refs <- function(engine, title = "Bibliography") {
  if (!isTRUE(.cv_state$cited)) return(invisible())
  # the bibliography starts on a new page
  cv_emit(if (engine == "typst") "#pagebreak()" else "\\newpage", engine)
  cv_heading(title, engine)
  cat("\n::: {#refs}\n:::\n")
}

# Free text (intro, asides) is plain Markdown that Pandoc converts itself.
# Tries each loc in order, e.g. c("intro_industry", "intro").
cv_print_text <- function(d, version, locs) {
  for (loc in locs) {
    t <- cv_text(d, version, loc)
    if (!is.na(t)) { cat("\n", t, "\n", sep = ""); return(invisible()) }
  }
}
