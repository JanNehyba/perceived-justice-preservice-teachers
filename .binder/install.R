# Balíčky pro reprodukci notebooků 10–50, skriptů a figur (auditováno proti library()
# a :: napříč analyzy/notebooks/*.qmd a analyzy/scripts/*.R, revize D29 9. 10. 2026).
# Binder instaluje verze z CRAN snapshotu dle runtime.txt; pro bitově přesnou
# reprodukci použijte lokálně renv::restore() nad analyzy/renv.lock.
install.packages(c(
  "dplyr", "tidyr", "readr", "stringr", "tibble", "purrr",   # příprava a čtení dat
  "readxl",                                                  # čtení xlsx (viněty)
  "ggplot2", "ragg",                                         # figury (fig_*.R)
  "lavaan", "semTools", "psych", "GPArotation",              # CFA, ESEM a psychometrie
  "BifactorIndicesCalculator",                               # bifaktorové indexy (kap. 7)
  "EGAnet", "qgraph", "bootnet", "NetworkComparisonTest",    # síťová psychometrie, NCT
  "networktools", "mgm", "igraph",                           # můstková centralita, prediktabilita
  "ordinal", "rstatix", "coin", "effectsize",                # CLMM, neparametrické testy (coin: wilcox_effsize), velikosti účinku
  "fpc", "tidyLPA", "mclust",                                # shlukování a analýza latentních profilů
  "cluster", "dendextend", "ape", "phangorn",                # typologie (stromy, tanglegram)
  "irr",                                                     # míry shody (Krippendorff, kappa)
  "knitr", "rmarkdown"                                       # render Quarto notebooků
))
