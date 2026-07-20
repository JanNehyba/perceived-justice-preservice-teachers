# Balíčky pro reprodukci notebooků 10–50 a figur (auditováno proti library()
# a :: napříč analyzy/). Binder instaluje čerstvé verze z CRAN; pro bitově přesnou
# reprodukci použijte lokálně renv::restore() nad renv.lock.
install.packages(c(
  "dplyr", "tidyr", "readr", "stringr", "tibble", "purrr",   # příprava a čtení dat
  "readxl",                                                  # čtení xlsx (viněty)
  "ggplot2",                                                 # figury (fig_*.R)
  "lavaan", "semTools", "psych",                             # CFA a psychometrie
  "EGAnet", "qgraph", "bootnet", "NetworkComparisonTest",    # síťová psychometrie, NCT
  "ordinal",                                                 # kumulativní smíšený model (CLMM)
  "fpc", "tidyLPA",                                          # shlukování a analýza latentních profilů
  "irr",                                                     # míry shody (Krippendorff, kappa)
  "knitr", "rmarkdown"                                       # render Quarto notebooků
))
