# Build the CV versions. Run `make` to see the options.
#   make academic | industry | teaching | all
#   make fetch              download the Google Sheet into data/
#   make <target> DATA=example   use the fake data in data/example/

.PHONY: help all academic industry teaching fetch example clean

ifeq ($(DATA),example)
export CV_DATA_DIR := $(CURDIR)/data/example
endif

help:
	@echo "make academic   LaTeX CV for the academic market  -> output/cv/academic.pdf"
	@echo "make industry   Typst CV for industry             -> output/cv/industry.pdf"
	@echo "make teaching   Typst CV focused on teaching      -> output/cv/teaching.pdf"
	@echo "make all        all three"
	@echo "make fetch      download the private Google Sheet into data/"
	@echo "make example    render all three with the fake example data"
	@echo "make clean      delete output/ and generated files"
	@echo "Add DATA=example to any render target to use data/example/."

academic industry teaching:
	quarto render cv/$@.qmd

all:
	quarto render

fetch:
	Rscript R/fetch_data.R

example:
	$(MAKE) all DATA=example

clean:
	rm -rf output cv/_author-*.yml cv/*.typ cv/*.log cv/*_files
