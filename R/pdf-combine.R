library(pdftools)
pdf_folder <- "data/"

paste0(
    pdf_folder, 
    list("research_statement.pdf",
        "teaching_statement.pdf",
        "HM-teaching_evaluations.pdf")
    ) |>
  pdf_combine(output = paste0(pdf_folder, "research-teaching-statment-evals.pdf"))


paste0(
    pdf_folder, 
    list(
        "research_statement.pdf",
        "HansMartinez-JMP.pdf",
        "teaching_statement.pdf",
        "HM-teaching_evaluations.pdf")
    ) |>
  pdf_combine(output = paste0(pdf_folder, "JMP-statements.pdf"))

paste0(
    list(
        "data/federal-reserve-bank-of-cleveland_joe-111477904.pdf",
        "output/cv/HansMartinezCV.pdf")
    ) |>
  pdf_combine(output = paste0(pdf_folder, "HansMartinezCV-Cleveland.pdf"))
