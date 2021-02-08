# install.packages("devtools")
devtools::install_github("nstrayer/datadrivencv")

# run ?datadrivencv::use_datadriven_cv to see more details
datadrivencv::use_datadriven_cv(
  full_name = "Hans Martinez",
  data_location = "https://docs.google.com/spreadsheets/d/1JoK4tb-81ruPrv553DzY-JSIKSaCR9TW80i8--qhuqE/edit?usp=sharing",
  pdf_location = "https://github.com/hans-mtz/DataCV/raw/master/hans_cv.pdf",
  html_location = "https://github.com/hans-mtz/DataCV",
  source_location = "https://github.com/hans-mtz/DataCV"
)
