#!/usr/bin/env Rscript
# Stabilita paralelní analýzy verze 2021 (revize 9. 10. 2026). Paralelní analýza je simulační:
# notebook 20_psychometrie.qmd ji spouští jednou (výchozích 20 simulací), a její doporučený počet
# faktorů proto závisí na počátečním stavu generátoru náhodných čísel. Skript ji opakuje pro deset
# počátečních stavů a zapisuje, kolikrát doporučila který počet faktorů.
# Zapisuje manifest vystupy/tabulky/06_parallel2021_cisla.csv (metric,value), nic jiného.
# Spouštět z habilitace-1/analyzy: Rscript scripts/parallel2021_stabilita.R
suppressPackageStartupMessages(library(psych))
ROOT <- Filter(function(p) dir.exists(file.path(p, "data", "processed")), c("..", ".", "../.."))[1]
d21 <- read.csv(file.path(ROOT, "data", "processed", "justice_2021_clean.csv"), check.names = FALSE)
X21 <- as.data.frame(lapply(d21, function(x) suppressWarnings(as.numeric(x))))
X21 <- X21[complete.cases(X21), , drop = FALSE]
seeds <- 1:10
nf <- sapply(seeds, function(s) {
  set.seed(s)
  invisible(capture.output(p <- suppressWarnings(
    fa.parallel(X21, cor = "poly", fa = "fa", plot = FALSE, fm = "minres"))))
  p$nfact
})
res <- list(pa2021_runs = length(seeds), pa2021_nfact_min = min(nf), pa2021_nfact_max = max(nf))
for (k in sort(unique(nf))) res[[paste0("pa2021_nfact_", k, "_count")]] <- sum(nf == k)
res$psych_version <- as.character(packageVersion("psych"))
out <- data.frame(metric = names(res), value = unlist(lapply(res, as.character)))
write.csv(out, file.path(ROOT, "vystupy", "tabulky", "06_parallel2021_cisla.csv"), row.names = FALSE)
print(out, row.names = FALSE)
