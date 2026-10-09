#!/usr/bin/env Rscript
# Citlivostní analýza: ordinální × přibližně intervalové pojetí sedmibodových položek (D19,
# revize 9. 10. 2026; odpověď na B6-231). Hlavní analýzy knihy se nemění.
# Srovnává EFA vlny 2023 na polychorických × Pearsonových korelacích (podíl celkového rozptylu,
# komunality, Tuckerova kongruence řešení) a shodu čtyřfaktorové CFA a ESEM odhadnutých WLSMV
# (ordinálně) × MLR (spojitě) na vlně 2024 a ověřovací kohortě 2026.
# Zapisuje manifest vystupy/tabulky/D3_citlivost_cisla.csv (metric,value). Zmrazený manifest vznikl
# v prostředí Binder (R 4.5.1, lavaan 0.6-21 a psych 2.6.5 podle renv.lock), 9. 10. 2026.
# Spouštět z habilitace-1/analyzy (renv): Rscript scripts/citlivost_ordinal.R
suppressPackageStartupMessages({ library(psych); library(lavaan) })
set.seed(744)
ROOT <- Filter(function(p) dir.exists(file.path(p, "data", "processed")), c("..", ".", "../.."))[1]
d <- read.csv(file.path(ROOT, "data", "processed", "justice_final.csv"))
ITEMS <- sprintf("item_%02d", 1:26)
MAP <- list(
  procedural = sprintf("item_%02d", c(1, 2, 6, 7, 8, 23, 24, 26)),
  equality   = sprintf("item_%02d", c(3, 10, 14, 15, 16, 22)),
  needs      = sprintf("item_%02d", c(4, 5, 9, 11, 17, 18)),
  merit      = sprintf("item_%02d", c(12, 13, 19, 20, 21, 25)))
X <- d[, ITEMS]; w <- split(seq_len(nrow(d)), d$wave)
X23 <- X[w[["2023"]], ]; X24 <- X[w[["2024"]], ]; X26 <- X[w[["2026"]], ]
res <- list(); put <- function(k, v) res[[k]] <<- v

fa_p <- fa(X23, nfactors = 4, fm = "minres", rotate = "oblimin", cor = "poly")
fa_r <- fa(X23, nfactors = 4, fm = "minres", rotate = "oblimin", cor = "cor")
for (nm in c("poly", "pearson")) {
  f <- if (nm == "poly") fa_p else fa_r
  put(paste0("efa23_", nm, "_var_total_pct"), round(sum(f$Vaccounted["Proportion Var", ]) * 100, 1))
  put(paste0("efa23_", nm, "_h2_median"), round(median(f$communality), 2))
  put(paste0("efa23_", nm, "_salient_ge_40"), sum(apply(abs(unclass(f$loadings)), 1, max) >= .40))
}
cong <- factor.congruence(fa_p, fa_r)
put("efa23_tucker_min", round(min(apply(abs(cong), 1, max)), 2))

syn <- paste(sapply(names(MAP), function(f) paste0(f, " =~ ", paste(MAP[[f]], collapse = " + "))), collapse = "\n")
esem <- paste(sapply(paste0("F", 1:4), function(f) paste0('efa("e1")*', f, " =~ ", paste(ITEMS, collapse = " + "))), collapse = "\n")
fitm <- function(model, data, ord, is_esem = FALSE) {
  args <- list(model = model, data = data, std.lv = TRUE)
  if (ord) { args$ordered <- ITEMS; args$estimator <- "WLSMV"; args$parameterization <- "theta" }
  else args$estimator <- "MLR"
  if (is_esem) args$rotation <- "geomin"
  f <- do.call(lavaan::cfa, args)
  fm <- fitMeasures(f, c("cfi.robust", "rmsea.robust", "srmr"))
  round(setNames(as.numeric(fm), c("cfi", "rmsea", "srmr")), 3)
}
for (spec in list(list("cfa4f_2024", syn, X24, FALSE), list("esem_2024", esem, X24, TRUE),
                  list("cfa4f_2026", syn, X26, FALSE))) {
  for (ord in c(TRUE, FALSE)) {
    r <- fitm(spec[[2]], spec[[3]], ord, spec[[4]])
    for (k in names(r)) put(paste0(spec[[1]], if (ord) "_wlsmv_" else "_mlr_", k), r[[k]])
  }
}
put("psych_version", as.character(packageVersion("psych")))
put("lavaan_version", as.character(packageVersion("lavaan")))
out <- data.frame(metric = names(res), value = unlist(lapply(res, as.character)))
write.csv(out, file.path(ROOT, "vystupy", "tabulky", "D3_citlivost_cisla.csv"), row.names = FALSE)
print(out, row.names = FALSE)
