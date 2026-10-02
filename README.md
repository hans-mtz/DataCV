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
3. From then on, refresh the data with `make fetch`, which writes `data/*.csv` (gitignored).
4. Render with `make academic`, `make industry`, `make teaching`, or `make all`.

No sheet? Put your own CSVs in `data/` with the same columns as `data/example/`. If `data/entries.csv` exists it is used; otherwise the example data is used. Add `DATA=example` to any command to force the example data.

## Data format

`entries.csv` (one row per CV line):

| Column | Meaning |
|---|---|
| `in_resume` | `TRUE`/`FALSE` master switch. `FALSE` hides the row everywhere. |
| `versions` | Which CVs show the row: `academic`, `industry`, `teaching`, or `all`. Separate several with `;`. |
| `section` | `education`, `research_positions`, `industry_positions`, `teaching_positions`, `academic_articles`, `working_papers`, `reports` |
| `priority` | Optional number. Within a section, lower numbers come first; blanks follow in sheet order. |
| `title`, `institution`, `loc`, `start`, `end`, `url` | For jobs and education: `institution` is the employer or school and `loc` the city. For papers and reports: `institution` is the journal or institute and `loc` the coauthors (`with A. Author`). |
| `description_1` ... `description_6` | Bullet points (or the abstract for working papers). |

`text_blocks.csv` has `version`, `loc`, `text`. Used keys: `intro` (or `intro_academic`, `intro_industry`, `intro_teaching`), `position` (the headline under your name), and the section asides `industry_experience_aside`, `publications_aside`, `wp_aside`, `teaching_experience_aside`.

`contact_info.csv` has `loc`, `icon`, `contact` (`[text](url)`). `language_skills.csv` has `skill`, `level`.

Text fields accept light Markdown: `*italic*`, `**bold**`, `[text](url)`.

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
