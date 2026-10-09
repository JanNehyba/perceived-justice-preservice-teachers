#!/usr/bin/env Rscript
# EFA pilotní verze 2 (2020): 23 normativních položek („Učitel by měl…"), n = 375.
# Doklad k rozhodnutí D5 (revize 9. 10. 2026): psychometrický důvod přechodu k verzi 3.
# Zapisuje manifest vystupy/tabulky/06_pilot2020_cisla.csv (metric,value), nic jiného.
# Spouštět z habilitace-1/analyzy (renv): Rscript scripts/efa2020_pilot.R
suppressPackageStartupMessages(library(psych))
set.seed(2020)
ROOT <- Filter(function(p) dir.exists(file.path(p, "data", "processed")), c("..", ".", "../.."))[1]
d <- read.csv(file.path(ROOT, "data", "processed", "justice_2020_clean.csv"), check.names = FALSE)
items <- grep("^b[0-9]+$", names(d), value = TRUE)
X <- as.data.frame(lapply(d[, items], as.numeric))
X <- X[complete.cases(X), ]
res <- list(n_2020_efa = nrow(X), k_items_2020 = ncol(X))
f <- fa(X, nfactors = 4, fm = "minres", rotate = "oblimin", cor = "poly")
h2 <- f$communality
res$var_2020_4f_pct <- round(sum(f$Vaccounted["Proportion Var", ]) * 100, 1)
res$h2_2020_median <- round(median(h2), 2)
res$h2_2020_below_30 <- sum(h2 < .30)
res$salient_2020_ge_40 <- sum(apply(abs(unclass(f$loadings)), 1, max) >= .40)
res$pct_at_7_2020 <- round(mean(as.matrix(X) == 7) * 100, 1)
res$psych_version <- as.character(packageVersion("psych"))
out <- data.frame(metric = names(res), value = unlist(lapply(res, as.character)))
write.csv(out, file.path(ROOT, "vystupy", "tabulky", "06_pilot2020_cisla.csv"), row.names = FALSE)
print(out, row.names = FALSE)
