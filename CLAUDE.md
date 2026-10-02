# DataCV

Data-driven academic CV. Data lives in a **private** Google Sheet (or local CSVs), R loads it, Quarto renders PDFs in three versions:

| Version | File | Engine | Focus |
|---|---|---|---|
| Academic | `cv/academic.qmd` | LaTeX (TinyTeX), design from `Latex/stevewong_template.tex` | Research, education, publications, research + teaching experience |
| Industry | `cv/industry.qmd` | Typst (`awesomecv-typst`) | Soft skills, private-sector/consulting/project-management experience |
| Teaching | `cv/teaching.qmd` | Typst (`awesomecv-typst`) | Courses taught, teaching roles |

## Privacy rules (public repo!)

- NEVER commit: the sheet ID or URL, real CV data (`data/*.csv`), rendered output (`*.pdf`, `*.html`, `output/`), photos, email/phone/address, `.Renviron`, `archive/`.
- Sheet ID and Google account come from `.Renviron` (`CV_SHEET_ID`, `CV_EMAIL`); see `.Renviron.example`. Never hard-code them.
- The sheet is Restricted; auth is via `googlesheets4::gs4_auth()` with a locally cached token. Do not use `gs4_deauth()`.
- Only fake data goes in `data/example/`. Before any commit, run `git status` and check no personal files are staged.
- Contact details in `.qmd` files must come from data/env, not be typed in.

## Layout

- `Makefile`: `make academic|industry|teaching|all|fetch|example|clean` (`DATA=example` forces the fake data)
- `R/fetch_data.R`: sheet -> `data/*.csv` (tabs: `entries`, `language_skills`, `text_blocks`, `contact_info`; first row of each tab is a note, so `skip = 1`)
- `R/prepare.R`: Quarto pre-render; writes `cv/_author-<version>.yml` (name, address from `.Renviron`; contacts from data; headline from text block `position`)
- `R/cv_helpers.R`: filters entries by `in_resume` + `versions` (`all` = every version), sorts by `priority`, emits Typst or LaTeX; light Markdown in text fields
- `cv/*.qmd`: the three CVs. Typst ones need the `brand:` block inline in the front matter (a `_brand.yml` or metadata file is not picked up by the template)
- `_extensions/kazuyanagimoto/awesomecv`: Typst design, edited locally (single-color section titles; brand icon font falls back to Font Awesome 7)
- `templates/academic/header.tex`: LaTeX design, from `Latex/stevewong_template.tex`
- `data/example/`: fake CSVs so others can run the template
- `archive/`: old R Markdown pipeline and Quarto experiments (gitignored, reference only)

## Data conventions

`institution` is the employer/school for jobs and education, but the journal/institute for `academic_articles`, `working_papers`, `reports`; for those, `loc` holds coauthors.

`language_skills` has an optional `type` column: `language` rows print as "Languages: Spanish (Native)"; blank/`software` rows are software, sorted by numeric level.

The academic LaTeX header shows email, website, GitHub, LinkedIn, Twitter with `fontawesome5` icons.

## Versioning of content

`entries` has `in_resume` (master switch; FALSE hides everywhere), `versions` (`academic;industry;teaching` or `all`) and optional `priority` (ascending within a section, blanks last). `text_blocks` has a `version` column. Each `.qmd` filters on its own version. Press sections are excluded (in_resume FALSE).

## Design

- Section titles: a single color for the whole title (currently accent `#1A4E8A`).
- Planned at the end: a minimalist palette of base / accent / dominant colors, shared across all three versions.

## Open items

- Sheet: add `position` text blocks (headline under the name), language rows (`type` = language), clear course `description_1` that duplicates the date, fix `versions` value `research`.
- Check Roboto / Source Sans fonts apply in the final Typst PDFs.
- Last step: propose a minimalist base/accent/dominant palette shared by all three versions.

## Commands

- Fetch data: `Rscript R/fetch_data.R`
- Render: `make academic` (or `industry`, `teaching`, `all`)
- Check setup: `quarto check` (Quarto >= 1.4 for Typst; TinyTeX for LaTeX)

## Conventions

- Match existing style; keep code minimal and commented only where non-obvious.
- Do not commit or push unless asked. History was reset once for privacy; do not force-push without explicit confirmation.
