# Render all three CV versions into output/cv/.
#   Rscript R/render_all.R            # uses data/ if present, else data/example/
#   Rscript R/render_all.R example    # force the fake example data
args <- commandArgs(trailingOnly = TRUE)
if ("example" %in% args) Sys.setenv(CV_DATA_DIR = file.path(getwd(), "data", "example"))

status <- system2("quarto", "render")
quit(status = status)
