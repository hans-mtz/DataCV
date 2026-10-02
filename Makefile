# Build the CV versions. Run `make` to see the options.
#
# Rendering reads the CSVs already in data/ (no Google call). Add FETCH=1 to
# download the sheet first. Make only re-renders when something it depends on
# changed: the .qmd, the R helpers, the templates, or the data.

.PHONY: help all academic industry teaching fetch example clean FORCE

# Data folder: data/ if you have fetched your sheet, else the fake examples.
# DATA=example forces the examples.
ifeq ($(DATA),example)
export CV_DATA_DIR := $(CURDIR)/data/example
DATA_DIR := data/example
else
DATA_DIR := $(if $(wildcard data/entries.csv),data,data/example)
endif

DATA_FILES := $(wildcard $(DATA_DIR)/*.csv) $(wildcard $(DATA_DIR)/*.bib)
COMMON := R/cv_helpers.R R/prepare.R _quarto.yml output/.data_dir $(DATA_FILES)
TYPST := _extensions/kazuyanagimoto/awesomecv/typst-template.typ

help:
	@echo "make academic   LaTeX CV for the academic market  -> output/cv/academic.pdf"
	@echo "make industry   Typst CV for industry             -> output/cv/industry.pdf"
	@echo "make teaching   Typst CV focused on teaching      -> output/cv/teaching.pdf"
	@echo "make all        all three"
	@echo "make fetch      download the private Google Sheet into data/"
	@echo "make example    render all three with the fake example data"
	@echo "make clean      delete output/ and generated files"
	@echo ""
	@echo "FETCH=1  download the sheet first, e.g. make academic FETCH=1"
	@echo "DATA=example  use data/example/ instead of data/"

# Remember which data folder the PDFs were built from, so switching between
# real and example data triggers a rebuild.
output/.data_dir: FORCE
	@mkdir -p output
	@echo "$(DATA_DIR)" | cmp -s - $@ || echo "$(DATA_DIR)" > $@

output/cv/academic.pdf: cv/academic.qmd templates/academic/header.tex $(COMMON)
	quarto render cv/academic.qmd

output/cv/industry.pdf: cv/industry.qmd $(TYPST) $(COMMON)
	quarto render cv/industry.qmd

output/cv/teaching.pdf: cv/teaching.qmd $(TYPST) $(COMMON)
	quarto render cv/teaching.qmd

# Fetch first (if asked) in a sub-make, so the data timestamps are re-read.
academic industry teaching:
	@$(if $(FETCH),$(MAKE) fetch &&) $(MAKE) output/cv/$@.pdf

all:
	@$(if $(FETCH),$(MAKE) fetch &&) $(MAKE) output/cv/academic.pdf output/cv/industry.pdf output/cv/teaching.pdf

fetch:
	Rscript R/fetch_data.R

example:
	$(MAKE) all DATA=example

clean:
	rm -rf output cv/_author-*.yml cv/*.typ cv/*.log cv/*_files
