#!/usr/bin/env Rscript
# =============================================================================
# typologie_respondentu.R
# Kap. 5 (studie 1, viněty, n = 315), oddíl 5.3.3 (v knize jen jednou větou, rozhodnutí autora 13. 10. 2026): obsahují data stabilní typy respondentů?
#
# Spuštění v referenčním prostředí (verze balíčků podle analyzy/renv.lock):
#   MSYS_NO_PATHCONV=1 docker run --rm --entrypoint /bin/bash \
#     -v "C:\\Users\\Nehyba\\habilitace\\habilitace-1:/hab" hab1-binder-test4 \
#     -lc "cd /hab/analyzy && Rscript --no-init-file scripts/typologie_respondentu.R"
# Ladicí běh se zmenšeným počtem opakování (výstupy jen do dočasné složky):
#   ... -lc "cd /hab/analyzy && TYPOLOGIE_QUICK=1 Rscript --no-init-file scripts/typologie_respondentu.R"
#
# Vstupy (jen čtení):
#   data/processed/vinety_final.csv
#   vystupy/tabulky/05_typologie_resp_stare_reseni_clenstvi.csv
#     = původní členství ve dvou skupinách (n = 218 a 97) z doby před 9. 10. 2026, doslovně
#       převzaté z gitu: git show fb0a876:habilitace-1/vystupy/tabulky/05_vinety_cluster_membership.csv
#       (sloupce resp_id a cluster; nic jiného).
# Výstupy: vystupy/tabulky/05_typologie_resp_*.csv, manifest 05_typologie_resp_cisla.csv (metric,value).
# Existující výstupy notebooku 10_vinety.qmd (05_cisla.csv, 05_vinety_*.csv) se NEMĚNÍ.
#
# -----------------------------------------------------------------------------
# KRITÉRIA „STABILNÍCH TYPŮ“ (stanovena 13. 10. 2026 PŘED prvním spuštěním skriptu;
# prahy převzaty ze zadání beze změny, doplněna jen jejich operacionalizace)
# -----------------------------------------------------------------------------
# Kandidátní metody (všechny nezávislé na pořadí řádků):
#   ward_kons  konsenzuální Ward (ward.D2 na z-skórech) přes N_PERM náhodných pořadí řádků;
#              výsledné rozdělení = průměrová vazba na 1 − matici spolupříslušnosti (Monti et al., 2003)
#   pam        PAM na z-skórech (eukleidovská vzdálenost), 20 náhodných startů (fun_pam)
#   kmeans     k-means na z-skórech, 100 startů (fun_kmeans)
#              (Komentář opraven 13. 10. 2026: dřívější znění hlavičky uvádělo 50 a 500 startů;
#              kód i oba plné běhy použily 20 a 100 startů.)
#   lpa_<M>    analýza latentních profilů (mclust) na původní škále 1–7, modely M ∈ {EEI, VVI, EEE, VVV},
#              výchozí start + 20 náhodných startů (hcRandomPairs), bere se nejvyšší věrohodnost
#   Ward v pevném pořadí a původní řešení 218/97 se uvádějí jen pro diagnózu (nejsou kandidáty).
# K1 Shoda: aspoň dvě kandidátní metody dají při stejném počtu skupin k (2–5) rozdělení s ARI ≥ 0,65.
# K2 Stabilita: v obou shodných řešeních má KAŽDÁ skupina průměrnou bootstrapovou Jaccardovu
#    podobnost ≥ 0,75 (fpc::clusterboot, bootstrap s vracením, B ≥ 500; Hennig, 2007).
# K3 Oddělení: u metod založených na vzdálenostech průměrná šířka siluety ≥ 0,25
#    (Kaufman & Rousseeuw, 1990); u LPA současně entropie ≥ 0,80, nejmenší profil ≥ 5 % vzorku
#    a bootstrapový LRT (mclustBootstrapLRT) podporuje právě k profilů: test (k−1) vs. k p < 0,05
#    a test k vs. (k+1) p ≥ 0,05.
# Řešení se vykládá jako stabilní typy, jen když některá dvojice metod splní K1 a obě metody K2 i K3.
# K4 (doplňková kontrola artefaktu, stanovena předem; Bauer & Curran, 2003): LPA předpokládá
#    normální rozdělení uvnitř profilů; u šikmých sedmibodových hodnocení může volit více profilů
#    i v jediné populaci. Proto se simuluje N_NULL datových souborů z jediné populace se stejnými
#    marginálními rozděleními a Spearmanovými korelacemi (gaussovská kopula). Pokud zlepšení BIC
#    proti jednomu profilu (model EEI) v pozorovaných datech nepřesahuje nulové rozdělení
#    (p = (1 + #{ΔBIC_null ≥ ΔBIC_obs}) / (N_NULL + 1) ≥ 0,05), nelze profily LPA vykládat jako
#    typy nad rámec tvaru rozdělení jednotlivých vinět. Totéž pro nejlepší siluetu k-means.
# -----------------------------------------------------------------------------
# Diagnóza původního řešení 218/97 (bez kritérií, popisně):
#   pořadí řádků v souboru; shodné profily a shodné vzdálenosti; Ward v souborovém pořadí;
#   1000 náhodných pořadí (kolikrát vznikne 218/97); citlivost na zaokrouhlení v posledních bitech;
#   z-skóry počítané jen v 64bitové přesnosti (aritmetika R na procesorech Apple Silicon).
# =============================================================================

options(mc.cores = 1, warn = 1, stringsAsFactors = FALSE)
suppressPackageStartupMessages({
  library(mclust); library(cluster); library(fpc)
})

QUICK   <- nzchar(Sys.getenv("TYPOLOGIE_QUICK"))   # jen ladění; do knihy jde plný běh
SEED    <- 20261013
N_PERM  <- if (QUICK) 40  else 1000   # náhodná pořadí řádků (diagnóza + konsenzuální Ward)
N_EPS   <- if (QUICK) 20  else 200    # perturbace vzdáleností v posledních bitech
N_DPERM <- if (QUICK) 40  else 1000   # pořadí řádků při z-skórech počítaných jen v 64bitové přesnosti
N_ULP   <- if (QUICK) 40  else 1000   # náhodné změny z-skórů o 1 ulp
B_BOOT  <- if (QUICK) 30  else 1000   # clusterboot (Ward, PAM, k-means, LPA)
B_KONS  <- if (QUICK) 20  else 500    # clusterboot konsenzuálního Warda (vnitřně N_KONS_IN pořadí)
B_LPA   <- if (QUICK) 10  else 500    # clusterboot LPA (každý fit = výchozí + N_START náhodných startů)
N_KONS_IN <- if (QUICK) 10 else 50
N_LRT   <- if (QUICK) 19  else 999    # mclustBootstrapLRT
N_NULL  <- if (QUICK) 10  else 200    # nulové simulace (K4)
N_START <- if (QUICK) 3   else 20     # náhodné starty LPA
N_LPA_PERM <- if (QUICK) 5 else 50    # citlivost LPA na pořadí řádků
KS      <- 2:5                        # počty skupin u shlukování
GS      <- 1:5                        # počty profilů u LPA
MODELY  <- c("EEI", "VVI", "EEE", "VVV")

# prahy kritérií (stanoveno předem)
KRIT <- list(ari = 0.65, jaccard = 0.75, silueta = 0.25, entropie = 0.80,
             min_podil = 0.05, alfa = 0.05)

# --- kořen habilitace-1 -------------------------------------------------------
find_root <- function() {
  for (p in c(".", "..", "../..", "../../..")) if (dir.exists(file.path(p, "data/processed"))) return(normalizePath(p))
  stop("Nenalezen kořen habilitace-1.")
}
ROOT <- find_root()
TAB_REAL <- file.path(ROOT, "vystupy", "tabulky")
TAB <- if (QUICK) tempdir() else TAB_REAL
cat("Režim:", if (QUICK) "LADICÍ (výstupy do tempdir)" else "PLNÝ", "| výstupy:", TAB, "\n")

MAN <- list()
put <- function(key, val) { MAN[[key]] <<- val; invisible(val) }
wcsv <- function(df, name) write.csv(df, file.path(TAB, name), row.names = FALSE)
for (nm in names(KRIT)) put(paste0("krit_", nm), KRIT[[nm]])
put("nastaveni_n_perm", N_PERM); put("nastaveni_b_boot", B_BOOT); put("nastaveni_b_kons", B_KONS)
put("nastaveni_n_kons_vnitrni", N_KONS_IN); put("nastaveni_n_lrt", N_LRT); put("nastaveni_n_null", N_NULL)
put("nastaveni_n_start_lpa", N_START); put("nastaveni_seed", SEED); put("nastaveni_b_lpa", B_LPA)

ARI <- function(a, b) mclust::adjustedRandIndex(a, b)
sil_of_dm <- function(cl) if (length(unique(cl)) < 2) NA_real_ else mean(silhouette(cl, dm)[, 3])
r3  <- function(x) round(x, 3)

# =============================================================================
# 0. Data
# =============================================================================
V   <- c("v_rovnost", "v_nahoda", "v_potreby", "v_zasluhy", "v_rovne_prilezitosti", "v_kasty")
LAB <- c(v_rovnost = "rovnost", v_nahoda = "nahoda", v_potreby = "potreby", v_zasluhy = "zasluhy",
         v_rovne_prilezitosti = "rovne_prilezitosti", v_kasty = "spol_skupiny")
d <- read.csv(file.path(ROOT, "data", "processed", "vinety_final.csv"))
stopifnot(nrow(d) == 315, sum(complete.cases(d[V])) == 315)
R <- as.matrix(d[V]); storage.mode(R) <- "double"     # původní škála 1–7 (LPA)
X <- scale(R)                                          # z-skóry (shlukování), jako notebook 10
n <- nrow(X)
dm <- dist(X)
put("n", n)

# =============================================================================
# 1. DIAGNÓZA původního řešení 218/97
# =============================================================================
cat("\n== 1. Diagnóza ==\n")
put("diag_soubor_serazen_podle_resp_id", identical(d$resp_id, sort(d$resp_id)))

# 1a) shodné profily a shodné vzdálenosti
klic <- apply(R, 1, paste, collapse = "")
put("diag_n_ruznych_profilu", length(unique(klic)))
put("diag_n_resp_se_shodnym_profilem", sum(duplicated(klic) | duplicated(klic, fromLast = TRUE)))
dv <- round(as.vector(dm), 10)
put("diag_n_par", length(dv))
put("diag_n_ruznych_vzdalenosti", length(unique(dv)))
cnt <- ave(dv, dv, FUN = length)
put("diag_podil_par_se_shodnou_vzdalenosti", r3(mean(cnt > 1)))

# 1b) původní členství: stejná data? (silueta a profily musí odpovídat dřívějšímu manifestu)
old <- read.csv(file.path(TAB_REAL, "05_typologie_resp_stare_reseni_clenstvi.csv"))
stopifnot(setequal(old$resp_id, d$resp_id))
cl_old <- old$cluster_stare[match(d$resp_id, old$resp_id)]
put("stare_n1", sum(cl_old == 1)); put("stare_n2", sum(cl_old == 2))
put("stare_silueta", r3(mean(silhouette(cl_old, dm)[, 3])))
for (v in V) for (g in 1:2) put(paste0("stare_prumer_", LAB[v], "_sk", g), round(mean(R[cl_old == g, v]), 2))

# 1c) Ward v pořadí souboru a v pořadí podle resp_id (jako notebook 10)
ward_k <- function(Xo, k) cutree(hclust(dist(Xo), "ward.D2"), k)
w2_soubor <- ward_k(X, 2)
o_id <- order(d$resp_id); w2_id <- integer(n); w2_id[o_id] <- ward_k(X[o_id, ], 2)
put("ward_soubor_k2_n_mensi", min(table(w2_soubor)))
put("ward_soubor_k2_n_vetsi", max(table(w2_soubor)))
put("ward_soubor_k2_silueta", r3(mean(silhouette(w2_soubor, dm)[, 3])))
put("ward_soubor_k2_ari_stare", r3(ARI(w2_soubor, cl_old)))
put("ward_resp_id_k2_ari_stare", r3(ARI(w2_id, cl_old)))

# 1d) citlivost na zaokrouhlení: (i) tatáž vzdálenost spočtená jinou aritmetikou,
#     (ii) N_EPS náhodných relativních perturbací o velikosti 1e-12 (o řády pod přesností dat)
sq <- rowSums(X^2)
D2 <- sqrt(pmax(outer(sq, sq, "+") - 2 * tcrossprod(X), 0))
dm_alt <- as.dist(D2)
put("diag_alt_aritmetika_max_rozdil", signif(max(abs(as.vector(dm_alt) - as.vector(dm))), 3))
put("diag_alt_aritmetika_podil_par_jiny_bit", r3(mean(as.vector(dm_alt) != as.vector(dm))))
w2_alt <- cutree(hclust(dm_alt, "ward.D2"), 2)
put("diag_alt_aritmetika_k2_ari_soubor", r3(ARI(w2_alt, w2_soubor)))
put("diag_alt_aritmetika_k2_ari_stare", r3(ARI(w2_alt, cl_old)))
put("diag_alt_aritmetika_k2_n_mensi", min(table(w2_alt)))
set.seed(SEED)
eps_ari_soubor <- eps_ari_old <- eps_nmin <- numeric(N_EPS)
for (e in seq_len(N_EPS)) {
  dp <- dm; dp[] <- as.vector(dm) * (1 + 1e-12 * runif(length(dv), -1, 1))
  cp <- cutree(hclust(dp, "ward.D2"), 2)
  eps_ari_soubor[e] <- ARI(cp, w2_soubor); eps_ari_old[e] <- ARI(cp, cl_old); eps_nmin[e] <- min(table(cp))
}
put("diag_eps_n", N_EPS)
put("diag_eps_podil_zmena_k2", r3(mean(eps_ari_soubor < 0.999)))
put("diag_eps_k2_ari_soubor_median", r3(median(eps_ari_soubor)))
put("diag_eps_k2_ari_stare_max", r3(max(eps_ari_old)))
put("diag_eps_k2_n_mensi_min", min(eps_nmin)); put("diag_eps_k2_n_mensi_max", max(eps_nmin))

# 1e) z-skóry se sčítáním jen v 64bitové přesnosti. R na procesorech Apple Silicon nemá long double
#     s rozšířenou přesností, takže colMeans() a sum() uvnitř scale() sčítají v double; na x86_64
#     (referenční prostředí) sčítají v 80bitové přesnosti. Rozdíl je v posledních bitech z-skórů.
kanon <- function(cl) paste(match(cl, unique(cl)), collapse = "")
dsum <- function(v) Reduce(`+`, v)
Xd <- R
for (j in seq_along(V)) { m <- dsum(R[, j]) / n; c0 <- R[, j] - m; Xd[, j] <- c0 / sqrt(dsum(c0^2) / (n - 1)) }
put("diag_n_z", length(X))
put("diag_double_n_zmenenych_z", sum(Xd != X))
put("diag_double_max_rozdil_z", signif(max(abs(Xd - X)), 2))
cl_d <- cutree(hclust(dist(Xd), "ward.D2"), 2)
put("diag_double_soubor_k2_ari_stare", r3(ARI(cl_d, cl_old)))
put("diag_double_soubor_k2_n_mensi", min(tabulate(cl_d)))
set.seed(SEED + 7)
dp_ari <- dp_nmin <- numeric(N_DPERM); dp_key <- character(N_DPERM)
for (i in seq_len(N_DPERM)) {
  o <- sample(n); cl <- integer(n); cl[o] <- cutree(hclust(dist(Xd[o, ]), "ward.D2"), 2)
  dp_ari[i] <- ARI(cl, cl_old); dp_nmin[i] <- min(tabulate(cl)); dp_key[i] <- kanon(cl)
}
put("diag_double_perm_n", N_DPERM)
put("diag_double_perm_n_reprodukuje_stare", sum(dp_ari > 0.999))
put("diag_double_perm_n_ruznych_rozdeleni", length(unique(dp_key)))
put("diag_double_perm_n_mensi_min", min(dp_nmin)); put("diag_double_perm_n_mensi_max", max(dp_nmin))
# 1f) náhodné změny z-skórů o 1 ulp (relativně 2^-52), polovina v pořadí souboru, polovina v náhodném
set.seed(SEED + 8)
ulp_ari <- ulp_nmin <- numeric(N_ULP); ulp_key <- character(N_ULP)
for (i in seq_len(N_ULP)) {
  Xp <- X * (1 + sample(c(-1, 0, 1), length(X), TRUE) * 2^-52)
  o <- if (i %% 2 == 0) seq_len(n) else sample(n)
  cl <- integer(n); cl[o] <- cutree(hclust(dist(Xp[o, ]), "ward.D2"), 2)
  ulp_ari[i] <- ARI(cl, cl_old); ulp_nmin[i] <- min(tabulate(cl)); ulp_key[i] <- kanon(cl)
}
put("diag_ulp_n", N_ULP)
put("diag_ulp_n_reprodukuje_stare", sum(ulp_ari > 0.999))
put("diag_ulp_n_ruznych_rozdeleni", length(unique(ulp_key)))
put("diag_ulp_n_mensi_min", min(ulp_nmin)); put("diag_ulp_n_mensi_max", max(ulp_nmin))
# 1g) Wardovo kritérium (vnitroskupinový součet čtverců, WSS; nižší = kompaktnější skupiny)
wss <- function(cl) sum(vapply(unique(cl), function(g) sum(scale(X[cl == g, , drop = FALSE], scale = FALSE)^2), numeric(1)))
put("wss_celkem", round(sum(scale(X, scale = FALSE)^2), 1))
put("wss_stare", round(wss(cl_old), 1))

# =============================================================================
# 2b-I. Ward přes N_PERM náhodných pořadí: diagnóza + konsenzuální rozdělení
# =============================================================================
cat("== Ward přes", N_PERM, "pořadí ==\n")
set.seed(SEED + 1)
P   <- array(0L, c(N_PERM, n, length(KS)))     # členství (v původním pořadí řádků)
SIL <- matrix(NA_real_, N_PERM, length(KS))
CM  <- lapply(KS, function(k) matrix(0, n, n))
onehot <- function(cl) { m <- matrix(0, length(cl), max(cl)); m[cbind(seq_along(cl), cl)] <- 1; m }
for (p in seq_len(N_PERM)) {
  o <- sample(n); Xo <- X[o, ]; dmo <- dist(Xo); hc <- hclust(dmo, "ward.D2")
  for (j in seq_along(KS)) {
    clo <- cutree(hc, KS[j]); SIL[p, j] <- mean(silhouette(clo, dmo)[, 3])
    cl <- integer(n); cl[o] <- clo; P[p, , j] <- cl
    CM[[j]] <- CM[[j]] + tcrossprod(onehot(cl))
  }
}
# volba k siluetou (jako notebook 10: k ∈ 2:4) a k ∈ 2:5
k_sil24 <- KS[1:3][apply(SIL[, 1:3, drop = FALSE], 1, which.max)]
for (k in 2:4) put(paste0("perm_volba_k", k, "_z_2az4"), sum(k_sil24 == k))
k_sil25 <- KS[apply(SIL, 1, which.max)]
for (k in KS) put(paste0("perm_volba_k", k, "_z_2az5"), sum(k_sil25 == k))
# k = 2: kolikrát vznikne původní 218/97, velikosti, oddělující viněta
ari_old_perm <- apply(P[, , 1], 1, ARI, cl_old)
nmin_perm    <- apply(P[, , 1], 1, function(cl) min(table(cl)))
put("perm_n", N_PERM)
put("perm_k2_n_reprodukuje_stare", sum(ari_old_perm > 0.999))
put("perm_k2_n_ari_stare_ge_065", sum(ari_old_perm >= 0.65))
put("perm_k2_ari_stare_max", r3(max(ari_old_perm)))
put("perm_k2_ari_stare_median", r3(median(ari_old_perm)))
put("perm_k2_n_mensi_min", min(nmin_perm)); put("perm_k2_n_mensi_max", max(nmin_perm))
put("perm_k2_n_mensi_median", median(nmin_perm))
put("perm_k2_n_ruznych_rozdeleni", length(unique(apply(P[, , 1], 1, function(cl) paste(match(cl, unique(cl)), collapse = "")))))
top_sep <- function(cl) { u <- sort(unique(cl)); names(which.max(abs(colMeans(X[cl == u[1], , drop = FALSE]) - colMeans(X[cl == u[2], , drop = FALSE])))) }
tops <- table(factor(apply(P[, , 1], 1, top_sep), levels = V))
for (v in V) put(paste0("perm_k2_oddeluje_", LAB[v]), as.integer(tops[v]))
put("stare_oddeluje", LAB[top_sep(cl_old)])
keys2 <- apply(P[, , 1], 1, kanon); tk <- sort(table(keys2), decreasing = TRUE)
w2_tab <- do.call(rbind, lapply(seq_along(tk), function(i) {
  cl <- P[match(names(tk)[i], keys2), , 1]
  data.frame(rozdeleni = i, pocet_poradi = as.integer(tk[i]), velikosti = paste(sort(tabulate(cl), decreasing = TRUE), collapse = "/"),
             n_mensi = min(tabulate(cl)), silueta = r3(sil_of_dm(cl)), wss = round(wss(cl), 1), ari_stare = r3(ARI(cl, cl_old)),
             oddeluje = LAB[top_sep(cl)])
}))
wcsv(w2_tab, "05_typologie_resp_ward_k2_rozdeleni.csv"); print(w2_tab)
for (i in seq_len(nrow(w2_tab))) { put(paste0("ward_k2_rozdeleni", i, "_pocet"), w2_tab$pocet_poradi[i])
  put(paste0("ward_k2_rozdeleni", i, "_n_mensi"), w2_tab$n_mensi[i]); put(paste0("ward_k2_rozdeleni", i, "_wss"), w2_tab$wss[i])
  put(paste0("ward_k2_rozdeleni", i, "_silueta"), w2_tab$silueta[i]) }
put("perm_k2_silueta_median", r3(median(SIL[, 1])))
put("perm_k2_silueta_max", r3(max(SIL[, 1])))

# konsenzus: PAC (podíl dvojic s nejednoznačnou spolupříslušností 0,1–0,9; Şenbabaoğlu et al., 2014),
# shoda mezi pořadími (ARI náhodných dvojic pořadí), konsenzuální rozdělení
set.seed(SEED + 2)
pairs_idx <- cbind(sample(N_PERM, 1000, TRUE), sample(N_PERM, 1000, TRUE))
pairs_idx <- pairs_idx[pairs_idx[, 1] != pairs_idx[, 2], , drop = FALSE]
cons <- list(); ward_perm_tab <- list()
for (j in seq_along(KS)) {
  k <- KS[j]; M <- CM[[j]] / N_PERM; ut <- M[upper.tri(M)]
  cons[[as.character(k)]] <- cutree(hclust(as.dist(1 - M), "average"), k)
  ari_pp <- apply(pairs_idx, 1, function(ix) ARI(P[ix[1], , j], P[ix[2], , j]))
  ari_pc <- apply(P[, , j], 1, ARI, cons[[as.character(k)]])
  ward_perm_tab[[j]] <- data.frame(
    k = k, n_poradi = N_PERM, volba_siluetou_2az5 = sum(k_sil25 == k),
    silueta_median = r3(median(SIL[, j])), silueta_min = r3(min(SIL[, j])), silueta_max = r3(max(SIL[, j])),
    pac = r3(mean(ut > 0.1 & ut < 0.9)),
    ari_mezi_poradimi_median = r3(median(ari_pp)), ari_mezi_poradimi_q10 = r3(quantile(ari_pp, 0.1)),
    ari_s_konsenzem_median = r3(median(ari_pc)),
    n_ruznych_rozdeleni = length(unique(apply(P[, , j], 1, function(cl) paste(match(cl, unique(cl)), collapse = "")))))
  put(paste0("ward_perm_k", k, "_pac"), r3(mean(ut > 0.1 & ut < 0.9)))
  put(paste0("ward_perm_k", k, "_ari_mezi_poradimi_median"), r3(median(ari_pp)))
}
ward_perm_tab <- do.call(rbind, ward_perm_tab)
wcsv(ward_perm_tab, "05_typologie_resp_ward_poradi.csv")
print(ward_perm_tab)

# =============================================================================
# 2b-II. PAM a k-means na z-skórech
# =============================================================================
cat("== PAM, k-means ==\n")
part <- list()      # part[[metoda]][[k]] = členství
sil  <- list()
sil_of <- function(cl) if (length(unique(cl)) < 2) NA_real_ else mean(silhouette(cl, dm)[, 3])
# Hlavní rozdělení PAM a k-means vznikají TOUTÉŽ funkcí a se stejným semínkem jako referenční
# rozdělení v clusterboot (ten po set.seed(SEED) nejprve shlukuje úplná data), aby se stabilita
# posuzovala přesně u vykládaného rozdělení.
fun_pam    <- function(data, k) pam(data, k, nstart = 20, cluster.only = TRUE)        # 20 náhodných startů
fun_kmeans <- function(data, k) kmeans(data, k, nstart = 100, iter.max = 100)$cluster  # 100 startů
for (k in KS) {
  kk <- as.character(k)
  part$ward_kons[[kk]] <- cons[[kk]]
  set.seed(SEED); part$pam[[kk]] <- as.integer(fun_pam(X, k))
  pm_build <- pam(X, k, cluster.only = TRUE)                                          # klasický BUILD
  put(paste0("pam_k", k, "_ari_build_vs_nstart"), r3(ARI(pm_build, part$pam[[kk]])))
  set.seed(SEED); part$kmeans[[kk]] <- as.integer(fun_kmeans(X, k))
  part$ward_pevne[[kk]] <- { cl <- integer(n); cl[o_id] <- ward_k(X[o_id, ], k); cl }
}
# citlivost klasického PAM (BUILD) na pořadí řádků, k = 2
set.seed(SEED + 3)
pam_build2 <- pam(X, 2, cluster.only = TRUE)
pam_perm_ari <- replicate(min(100, N_PERM), { o <- sample(n); cl <- integer(n); cl[o] <- pam(X[o, ], 2, cluster.only = TRUE); ARI(cl, pam_build2) })
put("pam_build_k2_ari_poradi_min", r3(min(pam_perm_ari)))
# více lokálních optim: kolik různých rozdělení dá PAM a k-means z jednotlivých náhodných startů (k = 2)?
set.seed(SEED + 6)
pam1 <- replicate(100, as.integer(pam(X, 2, nstart = 1, cluster.only = TRUE)))
km1  <- replicate(100, kmeans(X, 2, nstart = 1, iter.max = 100)$cluster)
put("pam_k2_jeden_start_ari_s_hlavnim_median", r3(median(apply(pam1, 2, ARI, part$pam[["2"]]))))
put("kmeans_k2_jeden_start_ari_s_hlavnim_median", r3(median(apply(km1, 2, ARI, part$kmeans[["2"]]))))
put("kmeans_k2_jeden_start_podil_shoda", r3(mean(apply(km1, 2, ARI, part$kmeans[["2"]]) > 0.999)))
put("wss_kmeans_k2", round(wss(part$kmeans[["2"]]), 1)); put("wss_ward_kons_k2", round(wss(part$ward_kons[["2"]]), 1))
put("wss_pam_k2", round(wss(part$pam[["2"]]), 1))

# =============================================================================
# 2a. LPA (mclust): modely × počty profilů, výchozí + náhodné starty
# =============================================================================
cat("== LPA ==\n")
entropie <- function(z) { G <- ncol(z); if (is.null(G) || G < 2) return(NA_real_)
  z <- pmax(z, 1e-300); 1 + sum(z * log(z)) / (nrow(z) * log(G)) }
# Výchozí start (hierarchické shlukování) + N_START náhodných startů s pevnými semínky; bere se
# nejvyšší věrohodnost. hcRandomPairs() volá set.seed(), proto se stav generátoru obnovuje
# (jinak by se uvnitř clusterboot opakoval stále týž bootstrapový výběr).
fit_lpa <- function(G, model, Y = R) {
  rs_old <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit(if (!is.null(rs_old)) assign(".Random.seed", rs_old, envir = globalenv()))
  best <- tryCatch(Mclust(Y, G = G, modelNames = model, verbose = FALSE), error = function(e) NULL)
  start <- if (is.null(best)) NA_character_ else "vychozi"
  if (G > 1) for (s in seq_len(N_START)) {
    f <- tryCatch(Mclust(Y, G = G, modelNames = model, verbose = FALSE,
                         initialization = list(hcPairs = hcRandomPairs(Y, seed = SEED + s))),
                  error = function(e) NULL)
    if (!is.null(f) && (is.null(best) || f$loglik > best$loglik + 1e-6)) { best <- f; start <- paste0("nahodny_", s) }
  }
  if (!is.null(best)) attr(best, "start") <- start
  best
}
lpa <- list(); lpa_rows <- list()
for (m in MODELY) for (G in GS) {
  f <- fit_lpa(G, m); lpa[[m]][[as.character(G)]] <- f
  if (is.null(f)) {
    lpa_rows[[length(lpa_rows) + 1]] <- data.frame(model = m, G = G, odhadnut = FALSE, loglik = NA, n_par = NA,
      BIC = NA, ICL = NA, entropie = NA, n_min = NA, podil_min = NA, velikosti = NA, start = NA, silueta = NA)
    next
  }
  tabc <- tabulate(f$classification, G)
  lpa_rows[[length(lpa_rows) + 1]] <- data.frame(
    model = m, G = G, odhadnut = TRUE, loglik = round(f$loglik, 2), n_par = f$df,
    BIC = round(-f$bic, 2), ICL = round(-mclust::icl(f), 2),        # konvence: nižší = lepší (jako tidyLPA)
    entropie = r3(entropie(f$z)), n_min = min(tabc), podil_min = r3(min(tabc) / n),
    velikosti = paste(sort(tabc, decreasing = TRUE), collapse = "/"), start = attr(f, "start"),
    silueta = r3(if (G > 1) sil_of(f$classification) else NA))
}
lpa_tab <- do.call(rbind, lpa_rows)

# bootstrapový LRT pro každý model (sekvenčně 1 vs 2, …, 5 vs 6)
cat("== bootstrapový LRT ==\n")
lrt_p <- list()
for (m in MODELY) {
  set.seed(SEED + 100 + match(m, MODELY))
  lr <- tryCatch(mclustBootstrapLRT(R, modelName = m, nboot = N_LRT, maxG = max(GS), verbose = FALSE),
                 error = function(e) { message("LRT ", m, ": ", conditionMessage(e)); NULL })
  pv <- rep(NA_real_, max(GS))
  if (!is.null(lr)) pv[seq_along(lr$p.value)] <- lr$p.value      # pv[g] = test g vs g+1
  lrt_p[[m]] <- pv
  podp <- which(pv >= KRIT$alfa)[1]                                 # nejmenší g, kde g vs g+1 nevýznamné
  put(paste0("lpa_", m, "_lrt_podporuje_G"), if (is.na(podp)) NA else podp)
  for (g in seq_len(max(GS))) put(paste0("lpa_", m, "_lrt_p_", g, "v", g + 1), signif(pv[g], 3))
}
lpa_tab$lrt_p_Gminus1_vs_G <- mapply(function(m, G) if (G == 1) NA else signif(lrt_p[[m]][G - 1], 3), lpa_tab$model, lpa_tab$G)
lpa_tab$lrt_p_G_vs_Gplus1  <- mapply(function(m, G) signif(lrt_p[[m]][G], 3), lpa_tab$model, lpa_tab$G)
wcsv(lpa_tab, "05_typologie_resp_lpa.csv")
print(lpa_tab)

ok <- lpa_tab$odhadnut & !is.na(lpa_tab$BIC)
best_row <- lpa_tab[ok, ][which.min(lpa_tab$BIC[ok]), ]
put("lpa_nejlepsi_bic_model", best_row$model); put("lpa_nejlepsi_bic_G", best_row$G)
put("lpa_nejlepsi_bic_hodnota", best_row$BIC)
best_icl <- lpa_tab[ok, ][which.min(lpa_tab$ICL[ok]), ]
put("lpa_nejlepsi_icl_model", best_icl$model); put("lpa_nejlepsi_icl_G", best_icl$G)
for (m in MODELY) {
  sub <- lpa_tab[lpa_tab$model == m & ok, ]
  if (nrow(sub)) { put(paste0("lpa_", m, "_bic_G"), sub$G[which.min(sub$BIC)]); put(paste0("lpa_", m, "_icl_G"), sub$G[which.min(sub$ICL)]) }
}
for (m in MODELY) for (G in KS) {
  f <- lpa[[m]][[as.character(G)]]
  if (!is.null(f)) part[[paste0("lpa_", m)]][[as.character(G)]] <- f$classification
}
# kontrola: EEI se 2 profily musí odpovídat notebooku 10 (tidyLPA model 1: n = 40/275, BIC 6822,75)
e2 <- lpa_tab[lpa_tab$model == "EEI" & lpa_tab$G == 2, ]
put("lpa_EEI_G2_bic", e2$BIC); put("lpa_EEI_G2_entropie", e2$entropie)
put("lpa_EEI_G2_n_min", e2$n_min); put("lpa_EEI_G2_podil_min", e2$podil_min)
put("lpa_EEI_G2_silueta", e2$silueta)

# citlivost LPA na pořadí řádků (výchozí start, který stojí na hierarchickém shlukování)
set.seed(SEED + 4)
lpa_perm <- t(replicate(N_LPA_PERM, {
  o <- sample(n); f <- Mclust(R[o, ], G = 2, modelNames = "EEI", verbose = FALSE)
  cl <- integer(n); cl[o] <- f$classification
  c(ari = ARI(cl, part$lpa_EEI[["2"]]), bic = -f$bic)
}))
put("lpa_EEI_G2_poradi_ari_min", r3(min(lpa_perm[, "ari"])))
put("lpa_EEI_G2_poradi_bic_rozdil_max", round(max(abs(lpa_perm[, "bic"] - e2$BIC)), 2))

# =============================================================================
# 2b-III. Bootstrapová stabilita (fpc::clusterboot, Jaccard)
# =============================================================================
cat("== clusterboot ==\n")
mk_out <- function(cl, k, nazev) {
  cl <- as.integer(cl)
  list(result = NULL, nc = k, clusterlist = lapply(seq_len(k), function(i) cl == i), partition = cl, clustermethod = nazev)
}
cbi_ward <- function(data, k) mk_out(cutree(hclust(dist(data), "ward.D2"), k), k, "ward")
cbi_ward_kons <- function(data, k) {
  m <- nrow(data); C <- matrix(0, m, m)
  for (i in seq_len(N_KONS_IN)) {
    o <- sample(m); cl <- integer(m); cl[o] <- cutree(hclust(dist(data[o, , drop = FALSE]), "ward.D2"), k)
    C <- C + tcrossprod(onehot(cl))
  }
  mk_out(cutree(hclust(as.dist(1 - C / N_KONS_IN), "average"), k), k, "ward_kons")
}
cbi_pam    <- function(data, k) mk_out(fun_pam(data, k), k, "pam")
cbi_kmeans <- function(data, k) mk_out(fun_kmeans(data, k), k, "kmeans")
LPA_SELHALO <- list()                                   # počty neodhadnutelných bootstrapových fitů
cbi_lpa    <- function(data, k, model) {
  f <- fit_lpa(k, model, Y = data)                        # stejná funkce jako hlavní odhad
  if (is.null(f)) { key <- paste0(model, "_", k); LPA_SELHALO[[key]] <<- c(LPA_SELHALO[[key]], 1L)
    return(mk_out(rep(1L, nrow(data)), k, "lpa_selhalo")) }
  mk_out(f$classification, k, "lpa")
}
run_cb <- function(data, fun, k, B, ...) {
  cb <- clusterboot(data, B = B, bootmethod = "boot", clustermethod = fun, k = k, seed = SEED, count = FALSE, ...)
  list(jac = cb$bootmean, part = cb$partition, n = tabulate(cb$partition, k))
}
cbres <- list()
for (k in KS) {
  kk <- as.character(k)
  cbres$ward_pevne[[kk]] <- run_cb(X[o_id, ], cbi_ward, k, B_BOOT)
  cbres$ward_pevne[[kk]]$part[o_id] <- cbres$ward_pevne[[kk]]$part           # zpět do pořadí souboru
  cbres$ward_kons[[kk]]  <- run_cb(X, cbi_ward_kons, k, B_KONS)
  cbres$pam[[kk]]        <- run_cb(X, cbi_pam, k, B_BOOT)
  cbres$kmeans[[kk]]     <- run_cb(X, cbi_kmeans, k, B_BOOT)
  cbres$lpa_EEI[[kk]]    <- run_cb(R, cbi_lpa, k, B_LPA, model = "EEI")
  cat("  k =", k, "hotovo\n")
}
# LPA ostatních modelů: při počtu profilů zvoleném BIC, ICL a bootstrapovým LRT a u každého řešení
# se siluetou ≥ 0,25 (aby byla posouzena stabilita každého řešení, které by mohlo splnit K3)
for (m in setdiff(MODELY, "EEI")) {
  Gs <- c(MAN[[paste0("lpa_", m, "_bic_G")]], MAN[[paste0("lpa_", m, "_icl_G")]], MAN[[paste0("lpa_", m, "_lrt_podporuje_G")]],
          lpa_tab$G[lpa_tab$model == m & !is.na(lpa_tab$silueta) & lpa_tab$silueta >= KRIT$silueta])
  Gs <- sort(unique(Gs[!is.na(Gs) & Gs %in% KS]))
  for (Gm in Gs) if (!is.null(part[[paste0("lpa_", m)]][[as.character(Gm)]]))
    cbres[[paste0("lpa_", m)]][[as.character(Gm)]] <- run_cb(R, cbi_lpa, Gm, B_LPA, model = m)
}
for (key in names(LPA_SELHALO)) put(paste0("clusterboot_lpa_", key, "_neodhadnuto"), sum(LPA_SELHALO[[key]]))

# =============================================================================
# 2c. Tabulka řešení, shoda metod (ARI) a kritéria
# =============================================================================
KAND <- c("ward_kons", "pam", "kmeans", paste0("lpa_", MODELY))
VSE  <- c(KAND, "ward_pevne")
sol_rows <- list()
for (met in VSE) for (k in KS) {
  kk <- as.character(k); cl <- part[[met]][[kk]]
  if (is.null(cl)) next
  cb <- cbres[[met]][[kk]]
  ari_ref <- if (!is.null(cb)) ARI(cb$part, cl) else NA
  jac <- if (!is.null(cb)) cb$jac else NULL
  is_lpa <- grepl("^lpa_", met)
  lr <- if (is_lpa) lpa_tab[lpa_tab$model == sub("lpa_", "", met) & lpa_tab$G == k, ] else NULL
  sol_rows[[length(sol_rows) + 1]] <- data.frame(
    metoda = met, k = k, velikosti = paste(sort(tabulate(cl, k), decreasing = TRUE), collapse = "/"),
    n_min = min(tabulate(cl, k)), silueta = r3(sil_of(cl)),
    entropie = if (is_lpa) lr$entropie else NA,
    jaccard_skupin = if (is.null(jac)) NA else paste(r3(jac[order(-tabulate(cb$part, k))]), collapse = "/"),
    jaccard_min = if (is.null(jac)) NA else r3(min(jac)), jaccard_prumer = if (is.null(jac)) NA else r3(mean(jac)),
    ari_reference_clusterboot = r3(ari_ref),
    lrt_podporuje_G = if (is_lpa) MAN[[paste0(met, "_lrt_podporuje_G")]] else NA)
}
sol_tab <- do.call(rbind, sol_rows)
# K3 pro každé řešení
sol_tab$K3 <- with(sol_tab, ifelse(grepl("^lpa_", metoda),
  !is.na(entropie) & entropie >= KRIT$entropie & n_min / n >= KRIT$min_podil & !is.na(lrt_podporuje_G) & lrt_podporuje_G == k,
  !is.na(silueta) & silueta >= KRIT$silueta))
sol_tab$K2 <- !is.na(sol_tab$jaccard_min) & sol_tab$jaccard_min >= KRIT$jaccard
wcsv(sol_tab, "05_typologie_resp_reseni.csv")
print(sol_tab)
for (i in seq_len(nrow(sol_tab))) {
  pre <- paste0(sol_tab$metoda[i], "_k", sol_tab$k[i])
  put(paste0(pre, "_silueta"), sol_tab$silueta[i]); put(paste0(pre, "_velikosti"), sol_tab$velikosti[i])
  put(paste0(pre, "_jaccard_min"), sol_tab$jaccard_min[i]); put(paste0(pre, "_jaccard_prumer"), sol_tab$jaccard_prumer[i])
}
put("silueta_max_kandidati", max(sol_tab$silueta[sol_tab$metoda %in% KAND], na.rm = TRUE))
put("jaccard_min_max_kandidati", max(sol_tab$jaccard_min[sol_tab$metoda %in% KAND], na.rm = TRUE))

# ARI mezi všemi dvojicemi metod při stejném k (+ původní řešení u k = 2)
ari_rows <- list(); krit_rows <- list()
for (k in KS) {
  kk <- as.character(k)
  mets <- VSE[vapply(VSE, function(mm) !is.null(part[[mm]][[kk]]), logical(1))]
  if (k == 2) { part$stare <- list("2" = cl_old); mets <- c(mets, "stare") }
  for (a in seq_along(mets)) for (b in seq_along(mets)) if (a < b) {
    A <- mets[a]; Bm <- mets[b]; ari <- r3(ARI(part[[A]][[kk]], part[[Bm]][[kk]]))
    ari_rows[[length(ari_rows) + 1]] <- data.frame(k = k, metoda_a = A, metoda_b = Bm, ari = ari)
    if (A %in% KAND && Bm %in% KAND) {
      sa <- sol_tab[sol_tab$metoda == A & sol_tab$k == k, ]; sb <- sol_tab[sol_tab$metoda == Bm & sol_tab$k == k, ]
      K1 <- ari >= KRIT$ari
      krit_rows[[length(krit_rows) + 1]] <- data.frame(k = k, metoda_a = A, metoda_b = Bm, ari = ari, K1 = K1,
        K2_a = sa$K2, K2_b = sb$K2, K3_a = sa$K3, K3_b = sb$K3, splneno = K1 && sa$K2 && sb$K2 && sa$K3 && sb$K3)
    }
  }
}
ari_tab  <- do.call(rbind, ari_rows);  wcsv(ari_tab, "05_typologie_resp_ari.csv")
krit_tab <- do.call(rbind, krit_rows); wcsv(krit_tab, "05_typologie_resp_kriteria.csv")
print(krit_tab[order(-krit_tab$ari), ][1:min(15, nrow(krit_tab)), ])
put("krit_n_dvojic", nrow(krit_tab))
put("krit_n_dvojic_K1", sum(krit_tab$K1))
put("krit_n_reseni_K2", sum(sol_tab$K2 & sol_tab$metoda %in% KAND))
put("krit_n_reseni_K3", sum(sol_tab$K3 & sol_tab$metoda %in% KAND))
put("krit_n_dvojic_splneno", sum(krit_tab$splneno))
put("verdikt_stabilni_typy", any(krit_tab$splneno))
put("ari_max_kandidati", max(krit_tab$ari))
amax <- krit_tab[which.max(krit_tab$ari), ]
put("ari_max_dvojice", paste0(amax$metoda_a, "~", amax$metoda_b, "_k", amax$k))
for (k in KS) { sub <- krit_tab[krit_tab$k == k, ]; put(paste0("ari_max_k", k), max(sub$ari)) }
a2 <- function(A, B) ari_tab$ari[ari_tab$k == 2 & ((ari_tab$metoda_a == A & ari_tab$metoda_b == B) | (ari_tab$metoda_a == B & ari_tab$metoda_b == A))]
for (mm in c("ward_kons", "pam", "kmeans", "lpa_EEI", "ward_pevne")) put(paste0("ari_k2_stare_", mm), a2("stare", mm))
put("ari_k2_lpa_EEI_kmeans", a2("lpa_EEI", "kmeans")); put("ari_k2_lpa_EEI_pam", a2("lpa_EEI", "pam"))
put("ari_k2_lpa_EEI_ward_kons", a2("lpa_EEI", "ward_kons")); put("ari_k2_pam_kmeans", a2("pam", "kmeans"))
put("ari_k2_ward_kons_kmeans", a2("ward_kons", "kmeans")); put("ari_k2_ward_kons_pam", a2("ward_kons", "pam"))

# =============================================================================
# 3. Popis opakujících se struktur (profily na škále 1–7, jednopoložková pravidla)
# =============================================================================
pravidlo <- function(cl) {      # nejlepší pravidlo „viněta ≥ t“ pro k = 2: přesnost rozřazení
  best <- c(acc = 0, v = NA, t = NA)
  for (v in V) for (t in 2:7) { r <- R[, v] >= t
    acc <- max(mean(r == (cl == 1)), mean(r == (cl == 2)))
    if (acc > best["acc"]) best <- c(acc = acc, v = match(v, V), t = t) }
  list(acc = unname(best["acc"]), v = V[best["v"]], t = unname(best["t"]))
}
prof_rows <- list()
popis <- list(stare = cl_old, ward_kons_k2 = part$ward_kons[["2"]], pam_k2 = part$pam[["2"]],
              kmeans_k2 = part$kmeans[["2"]], lpa_EEI_k2 = part$lpa_EEI[["2"]], lpa_EEE_k2 = part$lpa_EEE[["2"]])
for (nm in names(popis)) {
  cl <- popis[[nm]]; sz <- tabulate(cl); ordg <- order(-sz)
  pr <- pravidlo(cl)
  put(paste0("popis_", nm, "_oddeluje"), LAB[top_sep(cl)])
  put(paste0("popis_", nm, "_pravidlo_vineta"), LAB[pr$v]); put(paste0("popis_", nm, "_pravidlo_prah"), pr$t)
  put(paste0("popis_", nm, "_pravidlo_presnost"), round(pr$acc, 2))
  for (gi in seq_along(ordg)) {
    g <- ordg[gi]
    row <- data.frame(reseni = nm, skupina = gi, n = sz[g], procent = round(100 * sz[g] / n, 1))
    for (v in V) row[[LAB[v]]] <- round(mean(R[cl == g, v]), 2)
    prof_rows[[length(prof_rows) + 1]] <- row
    put(paste0("popis_", nm, "_sk", gi, "_n"), sz[g]); put(paste0("popis_", nm, "_sk", gi, "_procent"), round(100 * sz[g] / n, 1))
    for (v in V) put(paste0("popis_", nm, "_sk", gi, "_", LAB[v]), round(mean(R[cl == g, v]), 2))
  }
}
prof_tab <- do.call(rbind, prof_rows); wcsv(prof_tab, "05_typologie_resp_profily.csv"); print(prof_tab)

# tvar rozdělení viněty rovných příležitostí (rozdělení hodnot 1–7, koeficient bimodality)
bimod <- function(x) { n <- length(x); m <- mean(x); m2 <- mean((x - m)^2); g <- mean((x - m)^3) / m2^1.5
  k <- mean((x - m)^4) / m2^2 - 3; (g^2 + 1) / (k + 3 * (n - 1)^2 / ((n - 2) * (n - 3))) }
for (v in V) put(paste0("bimodalita_", LAB[v]), round(bimod(R[, v]), 2))
fr <- tabulate(R[, "v_rovne_prilezitosti"], 7)
for (h in 1:7) put(paste0("rovne_prilezitosti_hodnota", h, "_n"), fr[h])
put("rovne_prilezitosti_ge5_n", sum(R[, "v_rovne_prilezitosti"] >= 5))
put("rovne_prilezitosti_ge4_n", sum(R[, "v_rovne_prilezitosti"] >= 4))
put("rovne_prilezitosti_ge5_procento", round(100 * mean(R[, "v_rovne_prilezitosti"] >= 5), 1))
small <- which.min(tabulate(part$lpa_EEI[["2"]]))
put("lpa_EEI_k2_mala_ge5_n", sum(R[part$lpa_EEI[["2"]] == small, "v_rovne_prilezitosti"] >= 5))
put("lpa_EEI_k2_mala_ge4_n", sum(R[part$lpa_EEI[["2"]] == small, "v_rovne_prilezitosti"] >= 4))
jl <- cbres$lpa_EEI[["2"]]; put("lpa_EEI_k2_jaccard_mala", r3(jl$jac[which.min(jl$n)])); put("lpa_EEI_k2_jaccard_velka", r3(jl$jac[which.max(jl$n)]))
# malá skupina modelu EEE (2 profily): překryv s malou skupinou EEI a stabilita
ce <- part$lpa_EEE[["2"]]; small_e <- which.min(tabulate(ce))
put("lpa_EEE_k2_mala_n", sum(ce == small_e))
put("lpa_EEE_k2_mala_prekryv_s_EEI_mala", sum(ce == small_e & part$lpa_EEI[["2"]] == small))
put("ari_k2_lpa_EEI_lpa_EEE", a2("lpa_EEI", "lpa_EEE"))
je <- cbres$lpa_EEE[["2"]]; if (!is.null(je)) { put("lpa_EEE_k2_jaccard_mala", r3(je$jac[which.min(je$n)])); put("lpa_EEE_k2_jaccard_velka", r3(je$jac[which.max(je$n)])) }
# hlavní komponenta (jedna osa?): podíl rozptylu
pc <- prcomp(X); ev <- pc$sdev^2
put("pca_podil_pc1", r3(ev[1] / sum(ev))); put("pca_podil_pc2", r3(ev[2] / sum(ev)))
put("pca_n_vlastnich_cisel_gt1", sum(ev > 1))
put("pca_procento_pc1", round(100 * ev[1] / sum(ev), 1)); put("pca_procento_pc2", round(100 * ev[2] / sum(ev), 1))
ld <- pc$rotation[, 1]; if (ld["v_rovnost"] < 0) ld <- -ld                     # znaménko: rovnost kladně
for (v in V) put(paste0("pca_pc1_naboj_", LAB[v]), r3(ld[v]))
pc1 <- as.vector(X %*% ld)
put("pca_pc1_bimodalita", round(bimod(pc1), 2))
pc1_split <- as.integer(pc1 > median(pc1)) + 1L
for (mm in c("ward_kons", "pam", "kmeans", "lpa_EEI")) put(paste0("ari_k2_", mm, "_vs_pc1_median"), r3(ARI(part[[mm]][["2"]], pc1_split)))
for (mm in c("ward_kons", "pam", "kmeans")) { cl <- part[[mm]][["2"]]
  put(paste0("r_pb_k2_", mm, "_pc1"), r3(abs(cor(pc1, cl)))) }

# =============================================================================
# 4. K4: nulový model jediné populace (gaussovská kopula se stejnými marginálami)
# =============================================================================
cat("== nulový model ==\n")
rs <- cor(R, method = "spearman"); Rn <- 2 * sin(pi * rs / 6)
eg <- eigen(Rn, symmetric = TRUE); if (min(eg$values) <= 1e-8) Rn <- eg$vectors %*% diag(pmax(eg$values, 1e-6)) %*% t(eg$vectors)
L <- chol(Rn)
bic_curve <- function(Y) { b <- mclustBIC(Y, G = GS, modelNames = "EEI", verbose = FALSE); -as.vector(b[, "EEI"]) }
obs_bic <- bic_curve(R)                     # stejný (výchozí) start jako u nulových dat
obs_dbic <- obs_bic[1] - min(obs_bic, na.rm = TRUE)
put("obs_bic_EEI_vychozi_G", GS[which.min(obs_bic)])
km_best <- function(Z) { s <- sapply(KS, function(k) { cl <- kmeans(Z, k, nstart = 20, iter.max = 100)$cluster; mean(silhouette(cl, dist(Z))[, 3]) }); c(max(s), KS[which.max(s)]) }
set.seed(SEED + 5)
obs_km <- km_best(X)[1]                     # stejný postup (20 startů) jako u nulových dat
null_rows <- list(); rs_diff <- numeric(N_NULL)
for (s in seq_len(N_NULL)) {
  U <- pnorm(matrix(rnorm(n * 6), n) %*% L)
  Y <- sapply(1:6, function(j) quantile(R[, j], U[, j], type = 1, names = FALSE)); colnames(Y) <- V
  rs_diff[s] <- mean(abs(cor(Y, method = "spearman") - rs)[upper.tri(rs)])
  bc <- bic_curve(Y)
  f2 <- tryCatch(Mclust(Y, G = 2, modelNames = "EEI", verbose = FALSE), error = function(e) NULL)
  tb <- if (is.null(f2)) c(NA, NA) else tabulate(f2$classification, 2)
  kb <- km_best(scale(Y))
  null_rows[[s]] <- data.frame(sim = s, G_bic = GS[which.min(bc)], dBIC_1_vs_nejlepsi = round(bc[1] - min(bc, na.rm = TRUE), 2),
    entropie_G2 = if (is.null(f2)) NA else r3(entropie(f2$z)), podil_min_G2 = r3(min(tb) / n),
    oddeluje_G2 = if (is.null(f2)) NA else LAB[{ cl <- f2$classification; names(which.max(abs(colMeans(scale(Y)[cl == 1, , drop = FALSE]) - colMeans(scale(Y)[cl == 2, , drop = FALSE])))) }],
    kmeans_silueta_max = r3(kb[1]), kmeans_k = kb[2])
}
null_tab <- do.call(rbind, null_rows); wcsv(null_tab, "05_typologie_resp_nulovy_model.csv")
put("null_n", N_NULL)
put("null_spearman_prumerna_odchylka", r3(mean(rs_diff)))
put("null_podil_bic_G_ge2", r3(mean(null_tab$G_bic >= 2)))
put("null_podil_bic_G2", r3(mean(null_tab$G_bic == 2)))
put("null_podil_G2_entropie_ge080_min_ge5proc", r3(mean(null_tab$entropie_G2 >= KRIT$entropie & null_tab$podil_min_G2 >= KRIT$min_podil, na.rm = TRUE)))
put("null_entropie_G2_median", r3(median(null_tab$entropie_G2, na.rm = TRUE)))
put("null_procento_bic_G_ge2", round(100 * mean(null_tab$G_bic >= 2), 1))
put("null_procento_G2_entropie_ge080_min_ge5proc", round(100 * mean(null_tab$entropie_G2 >= KRIT$entropie & null_tab$podil_min_G2 >= KRIT$min_podil, na.rm = TRUE), 1))
put("null_procento_min_G2_median", round(100 * median(null_tab$podil_min_G2, na.rm = TRUE), 1))
put("null_podil_min_G2_median", r3(median(null_tab$podil_min_G2, na.rm = TRUE)))
tn <- table(factor(null_tab$oddeluje_G2, levels = LAB)); for (v in LAB) put(paste0("null_G2_oddeluje_", v), as.integer(tn[v]))
put("obs_dbic_EEI", round(obs_dbic, 2))
put("null_dbic_median", round(median(null_tab$dBIC_1_vs_nejlepsi), 2)); put("null_dbic_max", round(max(null_tab$dBIC_1_vs_nejlepsi), 2))
p_lpa <- (1 + sum(null_tab$dBIC_1_vs_nejlepsi >= obs_dbic)) / (N_NULL + 1)
put("K4_p_lpa_dbic", r3(p_lpa)); put("K4_lpa_nad_ramec_marginal", p_lpa < KRIT$alfa)
put("obs_kmeans_silueta_max", r3(obs_km))
put("null_kmeans_silueta_median", r3(median(null_tab$kmeans_silueta_max)))
p_km <- (1 + sum(null_tab$kmeans_silueta_max >= obs_km)) / (N_NULL + 1)
put("K4_p_kmeans_silueta", r3(p_km)); put("K4_kmeans_nad_ramec_marginal", p_km < KRIT$alfa)

# =============================================================================
# 5. Manifest
# =============================================================================
man <- data.frame(metric = names(MAN), value = vapply(MAN, function(x) as.character(x), character(1)), row.names = NULL)
wcsv(man, "05_typologie_resp_cisla.csv")
cat("\nZapsáno", nrow(man), "hodnot do", file.path(TAB, "05_typologie_resp_cisla.csv"), "\n")
cat("VERDIKT stabilní typy:", MAN$verdikt_stabilni_typy, "\n")
print(sessionInfo())
