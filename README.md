# DataCV

Build several versions of an academic CV from one data source (a private Google Sheet or local CSV files), using R and Quarto.

| Version | Command | Engine | Focus |
|---|---|---|---|
| Academic | `make academic` | LaTeX | Education, research, publications, research and teaching experience |
| Industry | `make industry` | Typst | Soft skills, private-sector and project experience |
| Teaching | `make teaching` | Typst | Courses taught and teaching roles |

PDFs are written to `output/cv/`.

## Requirements

- [Quarto](https://quarto.org) 1.4 or newer (bundles Typst)
- TinyTeX for the LaTeX version: `quarto install tinytex`
- R with `readr`, `yaml`, `googlesheets4` (only for fetching a sheet)
- The Font Awesome fonts (for the Typst contact icons)

## Try it with the example data

```
make example
```

This renders all three versions from the fake data in `data/example/`.

## Use your own data

1. Copy `.Renviron.example` to `.Renviron` (it is gitignored) and fill in your name, address and Google Sheet ID. Keep the sheet **Restricted**.
2. Log in to Google once from an interactive R session:
   ```r
   readRenviron(".Renviron"); source("R/fetch_data.R"); fetch_cv_data()
   ```
3. Render with `make academic`, `make industry`, `make teaching`, or `make all`. These use the CSVs already in `data/` and only rebuild what changed.
4. Pull the latest sheet with `make fetch`, or do both in one go: `make academic FETCH=1`. `fetch` leaves `data/` untouched if Google fails (for example a rate limit) and only rewrites files that changed.

While tuning the layout, `quarto preview cv/academic.qmd` re-renders the PDF in your browser each time you save the `.qmd`. It does not see sheet edits, so use `make academic FETCH=1` for content changes.

No sheet? Put your own CSVs in `data/` with the same columns as `data/example/`. If `data/entries.csv` exists it is used; otherwise the example data is used. Add `DATA=example` to any command to force the example data.

## Data format

`entries.csv` (one row per CV line):

| Column | Meaning |
|---|---|
| `in_resume` | `TRUE`/`FALSE` master switch. `FALSE` hides the row everywhere. |
| `versions` | Which CVs show the row: `academic`, `industry`, `teaching`, or `all`. Separate several with `;`. |
| `section` | `education`, `research_positions`, `industry_positions`, `teaching_positions`, `academic_articles`, `working_papers`, `reports`, `work_in_progress`, `conferences`, `references` |
| `priority` | Optional number. Within a section, lower numbers come first; blanks follow in sheet order. |
| `title`, `institution`, `loc`, `start`, `end`, `url`, `tag` | For jobs and education: `institution` is the employer or school and `loc` the city. For papers and reports: `institution` is the journal or institute and `loc` the coauthors (`with A. Author`). |
| `description_1` ... `description_6` | Bullet points (or the abstract for working papers). |

`text_blocks.csv` has `version`, `loc`, `text`. Used keys: `intro` (or `intro_academic`, `intro_industry`, `intro_teaching`), `position` (the headline under your name), `fields`, `subfields` and `teaching_fields` (the academic CV's "Research Interests": major fields, specializations, and what you can teach, e.g. `Industrial Organization; Public Economics`), and the section asides `industry_experience_aside`, `publications_aside`, `wp_aside`, `teaching_experience_aside`.

`contact_info.csv` has `loc`, `icon`, `contact` (`[text](url)`). `language_skills.csv` has `skill`, `level`.

**References (people).** Use `section` = `references`, one row per person: `title` = name, `description_1` = role (e.g. Ph.D. supervisor), `institution` = affiliation, `url` = email. They print in a two-column grid, ordered by `priority`, and `versions` decides which CVs list them. The bibliography of the abstract citations is a separate list at the end, titled "Bibliography".

Text fields accept light Markdown: `*italic*`, `**bold**`, `[text](url)` (no nesting like `***both***`).

**Abstracts at the end (academic CV).** The `description_*` cells of a `working_papers` row are printed as paragraphs under the paper's title in an "Abstracts" section at the end. Single line breaks inside a cell become new paragraphs. They can cite with `[@key]`, `@key` or `[@a; @b]`, using `data/references.bib` (BibTeX, gitignored); the cited works are listed in a "Bibliography" at the very end, only if something is cited. To change the citation style, add `csl: your-style.csl` to `cv/academic.qmd`.

**Conferences.** Rows with `section` = `conferences` print as a "Conferences" section (academic CV only) and only if there is at least one row. Use `title` for the paper, `tag` for the role (Presenter or Discussant), `institution` for the conference, `loc` for coauthors ("with ..."), and `end` for the year.

**Work in progress.** Rows with `section` = `work_in_progress` appear as a titles-only list (with coauthors from `loc`) between Working Papers and Publications. Abstracts or notes in `description_*` are kept in the sheet but not printed; to promote a project, change its section to `working_papers`.

**Job market paper.** Make it a `working_papers` row, put `Job Market Paper` in the `tag` column and `1` in `priority`. The tag prints in bold in the list of working papers and next to the title in the abstracts. Any entry can have a tag.

**Bullets only in some versions.** Start a `description_*` cell with `[[academic;teaching]] text` to show it only in those CVs, or `[[!industry]] text` to hide it from the industry CV. Bullets with no prefix appear everywhere.

**References (people).** Use `section` = `references`, one row per person: `title` = name, `description_1` = role (e.g. Ph.D. supervisor, Placement director), `institution` = affiliation, `url` = email. They print in a two-column grid, ordered by `priority`, and `versions` decides which CVs list them.

## Privacy

Your data, `.Renviron`, and rendered files are gitignored, so personal details stay out of the repo. Only `data/example/` (fake data) is committed.

## Layout

```
R/                 fetch_data.R, cv_helpers.R, prepare.R, render_all.R
cv/                academic.qmd, industry.qmd, teaching.qmd
templates/academic LaTeX design (header.tex)
_extensions/       Typst design (awesomecv-typst)
data/example/      fake data
Makefile           make help
```
