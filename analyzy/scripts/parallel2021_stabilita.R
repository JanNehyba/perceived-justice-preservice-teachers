#!/usr/bin/env Rscript
# Stabilita paralelní analýzy verze 2021 (revize 9. 10. 2026). Paralelní analýza je simulační:
# notebook 20_psychometrie.qmd ji spouští jednou (výchozích 20 simulací), a její doporučený počet
# faktorů proto závisí na počátečním stavu generátoru náhodných čísel. Skript ji opakuje pro deset
# počátečních stavů a zapisuje, kolikrát doporučila který počet faktorů.
# Zapisuje manifesty vystupy/tabulky/06_parallel2021_cisla.csv a 07_parallel2023_cisla.csv (metric,value).
# Spouštět z habilitace-1/analyzy: Rscript scripts/parallel2021_stabilita.R
suppressPackageStartupMessages(library(psych))
# Sériový běh: ve forkovaných procesech mclapply set.seed neplatí (audit 13. 10. 2026).
options(mc.cores = 1)
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

# Totéž pro explorační vlnu 2023 finálního nástroje (doplněno 13. 10. 2026 po kontrole G3):
# zapisuje vystupy/tabulky/07_parallel2023_cisla.csv. Data a volání jako v 20_psychometrie.qmd (chunk efa2023).
ITEMS <- sprintf("item_%02d", 1:26)
dfin <- read.csv(file.path(ROOT, "data", "processed", "justice_final.csv"))
X23 <- dfin[dfin$wave == 2023, ITEMS]
nf23 <- sapply(seeds, function(s) {
  set.seed(s)
  invisible(capture.output(p <- suppressWarnings(
    fa.parallel(X23, cor = "poly", fa = "fa", plot = FALSE, fm = "minres"))))
  p$nfact
})
res23 <- list(pa2023_runs = length(seeds), pa2023_nfact_min = min(nf23), pa2023_nfact_max = max(nf23))
for (k in sort(unique(nf23))) res23[[paste0("pa2023_nfact_", k, "_count")]] <- sum(nf23 == k)
res23$psych_version <- as.character(packageVersion("psych"))
out23 <- data.frame(metric = names(res23), value = unlist(lapply(res23, as.character)))
write.csv(out23, file.path(ROOT, "vystupy", "tabulky", "07_parallel2023_cisla.csv"), row.names = FALSE)
print(out23, row.names = FALSE)
