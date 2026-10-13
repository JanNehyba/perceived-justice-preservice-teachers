#!/usr/bin/env Rscript
# Reliabilita skutečně používaného skóru subškál (audit A07, 13. 10. 2026).
#
# Spouštět v Dockeru (verze balíčků podle renv.lock) z analyzy/:
#   Rscript --no-init-file scripts/reliabilita_kompozit.R
# (--no-init-file: v kontejneru jsou balíčky v systémové knihovně, renv se neaktivuje.)
# Vstup: data/processed/justice_final.csv (jen čtení).
# Výstup: vystupy/tabulky/07_reliabilita_kompozit_cisla.csv (metric,value).
#
# Pro každou ze čtyř subškál (čtyřfaktorový model, mapování položek jako 20_psychometrie.qmd)
# a pro vlnu 2024 (konfirmační, n = 333), vlnu 2026 (ověřovací, n = 164) a sloučený vzorek
# (n = 744; z něj počítá faktorové skóry 30_network.qmd) se počítá:
#  (a) alpha<vv>_<p>: Cronbachova alfa pozorovaného (surového) součtu položek, psych::alpha.
#  (b) omega_sum<vv>_<p>: omega pozorovaného jednotkově váženého součtu z CFA na pozorovaných
#      položkách (MLR, std.lv = TRUE, korelované faktory, bez reziduálních kovariancí):
#      (Σλ)² / ((Σλ)² + Σθ) z NEstandardizovaných nábojů λ a reziduálních rozptylů θ.
#  (c) fs_det<vv>_<p>: determinace faktorových skórů ordinálního modelu WLSMV (theta
#      parametrizace, std.lv = TRUE, tentýž model jako v notebooku 20 a 30), tj. korelace
#      regresního faktorového skóru se skutečným faktorem, vzorcem
#      ρ = sqrt(diag(Φ Λ' R*⁻¹ Λ Φ)), kde Λ jsou standardizované náboje (škála latentních
#      odpovědí y*), Φ faktorové korelace a R* = Λ Φ Λ' + diag(1 − komunalita) modelová
#      (polychorická) korelační matice y*. Jde o determinaci skórů odhadnutých z y*; skóry
#      z kategoriálních odpovědí ji nemohou překročit (horní mez).
#      Kontrola: fs_det_sim<vv>_<p> = korelace skutečného faktoru se skóry, které lavaan
#      skutečně počítá z ordinálních odpovědí (lavPredict, metoda EBM, tj. výchozí volání
#      v 30_network.qmd), na N = 3 000 případech simulovaných z odhadnutého modelu
#      (η ~ N(0, Φ); y* = Λη + ε, ε ~ N(0, Θ); kategorie podle odhadnutých prahů).
#  (d) omega_gy<vv>_<p>: doplňkově ordinální omega pozorovaného součtu (Green & Yang, 2009):
#      rozptyl pravého skóru součtu E[S | η] přes bivariátní normální pravděpodobnosti prahů
#      a nábojů ordinálního modelu, dělený MODELOVÝM rozptylem součtu (týmiž vzorci s plnou
#      modelovou korelací; rozptyly položek z marginálních pravděpodobností). Varianta
#      s pozorovaným rozptylem součtu ve jmenovateli se nepoužívá: model při slabší shodě
#      nadhodnocuje kovariance mezi položkami (u procedurální spravedlnosti 2024 o 12 %),
#      takže by čitatel a jmenovatel pocházely z různých zdrojů a poměr by byl nadsazený.
#      (semTools::compRelSEM(ord.scale = TRUE) v této verzi končí chybou.)
# Krátké názvy principů: proc = procedurální, equal = rovnost, needs = potřeby, merit = zásluhy.
suppressPackageStartupMessages({ library(lavaan); library(psych) })
set.seed(20261013)

find_root <- function() {
  for (p in c(".", "..", "../..")) if (dir.exists(file.path(p, "data/processed"))) return(normalizePath(p))
  stop("root not found")
}
ROOT <- find_root()
PROC <- file.path(ROOT, "data", "processed")
TAB  <- file.path(ROOT, "vystupy", "tabulky")

ITEMS <- sprintf("item_%02d", 1:26)
MAP <- list(
  procedural = sprintf("item_%02d", c(1,2,6,7,8,23,24,26)),
  equality   = sprintf("item_%02d", c(3,10,14,15,16,22)),
  needs      = sprintf("item_%02d", c(4,5,9,11,17,18)),
  merit      = sprintf("item_%02d", c(12,13,19,20,21,25)))
SHORT <- c(procedural = "proc", equality = "equal", needs = "needs", merit = "merit")
m4F <- paste(sapply(names(MAP), function(f) paste0(f, " =~ ", paste(MAP[[f]], collapse = " + "))),
             collapse = "\n")

d <- read.csv(file.path(PROC, "justice_final.csv"))
SETS <- list("24" = d[d$wave == 2024, ITEMS], "26" = d[d$wave == 2026, ITEMS], "_pooled" = d[, ITEMS])
stopifnot(nrow(SETS[["24"]]) == 333, nrow(SETS[["26"]]) == 164, nrow(SETS[["_pooled"]]) == 744)

MAN <- list(); put <- function(k, v) { MAN[[k]] <<- v; invisible(v) }
put("rel_note", paste("alpha = raw-sum Cronbach; omega_sum = MLR CFA unit-weighted observed sum;",
                      "omega_gy = Green-Yang ordinal omega of the observed sum (model-implied variance of the sum);",
                      "fs_det = factor-score determinacy (latent-response formula, WLSMV theta);",
                      "fs_det_sim = r(EBM score, true factor), simulated N=3000"))

# --- standardized ordinal model pieces (theta parameterization -> y* scale) ---
std_pieces <- function(fit) {
  est <- lavInspect(fit, "est")
  Lam <- est$lambda[ITEMS, names(MAP)]; Phi <- est$psi[names(MAP), names(MAP)]
  Th  <- diag(est$theta[ITEMS, ITEMS])
  v   <- diag(Lam %*% Phi %*% t(Lam)) + Th            # var(y*) per item
  list(Lam = Lam, Phi = Phi, Th = Th, sd = sqrt(v), Ls = Lam / sqrt(v), tau = est$tau[, 1])
}

# --- (c) analytic determinacy on the latent-response scale ---
fs_det_formula <- function(P) {
  Rs <- P$Ls %*% P$Phi %*% t(P$Ls); diag(Rs) <- 1
  M <- P$Phi %*% t(P$Ls) %*% solve(Rs, P$Ls %*% P$Phi)
  setNames(sqrt(diag(M) / diag(P$Phi)), names(MAP))
}

# --- (c) check: simulate from the fitted model, score with lavPredict (EBM), correlate ---
fs_det_sim <- function(fit, X, P, N = 3000) {
  eta <- MASS::mvrnorm(N, rep(0, ncol(P$Phi)), P$Phi)
  ystar <- eta %*% t(P$Lam) + sweep(matrix(rnorm(N * length(ITEMS)), N), 2, sqrt(P$Th), "*")
  sim <- as.data.frame(lapply(seq_along(ITEMS), function(i) {
    it <- ITEMS[i]; lev <- sort(unique(X[[it]]))
    th <- P$tau[grep(paste0("^", it, "\\|t"), names(P$tau))]
    stopifnot(length(th) == length(lev) - 1)
    lev[findInterval(ystar[, i], th) + 1]               # category label as observed in the data
  })); names(sim) <- ITEMS
  # lavaan requires newdata to contain every observed category of every ordered item. For each
  # category absent from the simulated sample, one original row carrying it is appended; rows
  # are scored independently, and the appended rows must reproduce lavPredict(fit) exactly
  # (this also checks that categories are mapped as in the original data).
  add <- integer(0)
  for (it in ITEMS) for (lv in setdiff(unique(X[[it]]), unique(sim[[it]])))
    add <- c(add, which(X[[it]] == lv)[1])
  add <- unique(add)
  fs_all <- lavPredict(fit, newdata = rbind(sim, X[add, ITEMS]))
  if (length(add))
    stopifnot(max(abs(fs_all[N + seq_along(add), , drop = FALSE] - lavPredict(fit)[add, , drop = FALSE])) < 1e-6)
  fs <- fs_all[seq_len(N), names(MAP)]
  setNames(sapply(seq_along(MAP), function(j) cor(fs[, j], eta[, j])), names(MAP))
}

# --- (d) Green & Yang (2009) ordinal omega of the observed sum ---
omega_gy <- function(X, P, items) {
  Phi1 <- function(t) pnorm(t)
  Phi2 <- function(a, b, r) pbivnorm::pbivnorm(a, b, rho = r)
  steps <- lapply(items, function(it) diff(sort(unique(X[[it]]))))
  taus  <- lapply(items, function(it) {
    j <- match(it, ITEMS); P$tau[grep(paste0("^", it, "\\|t"), names(P$tau))] / P$sd[j] })
  ls <- P$Ls[items, , drop = FALSE]; ls <- ls[, colSums(ls != 0) > 0]   # one factor per subscale
  covT <- 0; varS <- 0
  for (a in seq_along(items)) for (b in seq_along(items)) {
    ta <- taus[[a]]; tb <- taus[[b]]; sa <- steps[[a]]; sb <- steps[[b]]
    rT <- ls[a] * ls[b]                                   # true-score part (i = j: λ²)
    G <- outer(seq_along(ta), seq_along(tb), function(i, j)
      Phi2(-ta[i], -tb[j], rT) - Phi1(-ta[i]) * Phi1(-tb[j]))
    covT <- covT + sum(outer(sa, sb) * G)
    # model-implied covariance of the observed items (i = j: item variance from the marginals)
    if (a == b) G <- outer(seq_along(ta), seq_along(ta), function(i, j)
      Phi1(-pmax(ta[i], ta[j])) - Phi1(-ta[i]) * Phi1(-ta[j]))
    varS <- varS + sum(outer(sa, sb) * G)
  }
  covT / varS
}

out_tab <- list()
for (vv in names(SETS)) {
  X <- SETS[[vv]]
  # (a) alpha of the raw sum
  for (p in names(MAP))
    put(paste0("alpha", vv, "_", SHORT[[p]]),
        round(suppressWarnings(psych::alpha(X[, MAP[[p]]], check.keys = FALSE)$total$raw_alpha), 3))
  # (b) omega of the observed unit-weighted sum, MLR CFA on observed items
  fm <- cfa(m4F, data = X, estimator = "MLR", std.lv = TRUE)
  stopifnot(lavInspect(fm, "converged"))
  em <- lavInspect(fm, "est")
  for (p in names(MAP)) {
    lam <- em$lambda[MAP[[p]], p]; th <- diag(em$theta)[MAP[[p]]]
    put(paste0("omega_sum", vv, "_", SHORT[[p]]), round(sum(lam)^2 / (sum(lam)^2 + sum(th)), 3))
  }
  # (c) + (d) ordinal WLSMV model (same specification as notebooks 20 and 30)
  fo <- cfa(m4F, data = X, ordered = ITEMS, estimator = "WLSMV", parameterization = "theta", std.lv = TRUE)
  stopifnot(lavInspect(fo, "converged"))
  P <- std_pieces(fo)
  # sanity: standardized loadings equal lavaan's std.all
  ss <- standardizedSolution(fo); ss <- ss[ss$op == "=~", ]
  stopifnot(max(abs(ss$est.std - P$Ls[cbind(ss$rhs, ss$lhs)])) < 1e-8)
  det_f <- fs_det_formula(P)
  det_s <- fs_det_sim(fo, X, P)
  for (p in names(MAP)) {
    put(paste0("fs_det", vv, "_", SHORT[[p]]), round(det_f[[p]], 3))
    put(paste0("fs_det_sim", vv, "_", SHORT[[p]]), round(det_s[[p]], 3))
    put(paste0("omega_gy", vv, "_", SHORT[[p]]), round(omega_gy(X, P, MAP[[p]]), 3))
  }
  for (k in c("alpha", "omega_sum", "omega_gy", "fs_det", "fs_det_sim")) {
    v <- sapply(SHORT, function(s) MAN[[paste0(k, vv, "_", s)]])
    put(paste0(k, vv, "_min"), min(v)); put(paste0(k, vv, "_max"), max(v))
  }
  out_tab[[vv]] <- data.frame(set = vv, principle = names(MAP),
    alpha = sapply(SHORT, function(s) MAN[[paste0("alpha", vv, "_", s)]]),
    omega_sum = sapply(SHORT, function(s) MAN[[paste0("omega_sum", vv, "_", s)]]),
    omega_gy = sapply(SHORT, function(s) MAN[[paste0("omega_gy", vv, "_", s)]]),
    fs_det = sapply(SHORT, function(s) MAN[[paste0("fs_det", vv, "_", s)]]),
    fs_det_sim = sapply(SHORT, function(s) MAN[[paste0("fs_det_sim", vv, "_", s)]]))
}
print(do.call(rbind, out_tab), row.names = FALSE)

w <- data.frame(metric = names(MAN), value = vapply(MAN, function(x) as.character(x[1]), character(1)))
write.csv(w, file.path(TAB, "07_reliabilita_kompozit_cisla.csv"), row.names = FALSE)
cat("Wrote 07_reliabilita_kompozit_cisla.csv (", nrow(w), " metrics)\n", sep = "")
