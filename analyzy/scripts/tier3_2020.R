#!/usr/bin/env Rscript
# Tier 3 (E4): configural check of the 2020 normative cohort on the author-confirmed
# item pairings (item_map_full.csv, 6 former REVIEW flags confirmed 11 Jul 2026).
# Mirrors the Tier-2 logic of 40_crosswave.qmd: EFA(4, polychoric) congruence vs the
# 2023 reference loadings + EGA community recovery vs a-priori principles.
# Appends results to vystupy/tabulky/08_cisla.csv (does not clobber other keys).
suppressPackageStartupMessages({library(psych); library(EGAnet); library(mclust)})
PROC <- Filter(dir.exists, c("../data/processed","data/processed"))[1]
TAB  <- file.path(PROC,"..","..","vystupy","tabulky")
set.seed(2020)

imf <- read.csv(file.path(PROC,"item_map_full.csv"), stringsAsFactors=FALSE)
stopifnot(!any(grepl("REVIEW", c(imf$match_2020B, imf$match_2019A))))   # pairings confirmed
map20 <- imf[!is.na(imf$id_2020B) & imf$id_2020B != "", c("item_id_final","principle","id_2020B")]
map20$final_col <- sprintf("item_%02d", as.integer(map20$item_id_final))
map20$b_col     <- sprintf("b%02d",     as.integer(map20$id_2020B))

d20 <- read.csv(file.path(PROC,"justice_2020_clean.csv"))
stopifnot(all(map20$b_col %in% names(d20)))
X20 <- d20[, map20$b_col]; names(X20) <- map20$final_col
X20 <- X20[complete.cases(X20), ]
apriori <- setNames(map20$principle, map20$final_col)
cat(sprintf("Tier 3 (2020): n=%d complete of %d; %d aligned items (%s)\n",
    nrow(X20), nrow(d20), nrow(map20),
    paste(names(table(map20$principle)), table(map20$principle), sep="=", collapse=", ")))

# --- configural EFA: 4 factors on polychorics, congruence vs 2023 reference loadings ---
Lref <- as.matrix(read.csv(file.path(TAB,"07_efa2023_loadings.csv"), row.names=1))
Lref <- Lref[map20$final_col, ]
L20 <- tryCatch(unclass(psych::fa(X20, nfactors=4, fm="minres", rotate="oblimin",
                                  cor="poly")$loadings),
                error=function(e){message("EFA20: ",conditionMessage(e)); NULL})
cg20 <- if(is.null(L20)) rep(NA_real_,4) else {
  cc <- psych::factor.congruence(L20, Lref)
  sapply(seq_len(ncol(Lref)), function(j) max(abs(cc[,j])))
}
names(cg20) <- colnames(Lref)
print(round(cg20,3))
write.csv(data.frame(reference_factor=colnames(Lref), congruence_2020=round(cg20,3)),
          file.path(TAB,"08_tier3_congruence.csv"), row.names=FALSE)

# --- configural EGA: how many communities, and do they align with the principles? ---
e20 <- tryCatch(EGA(X20, model="glasso", algorithm="walktrap", plot.EGA=FALSE),
                error=function(e) NULL)
ndim <- if(is.null(e20)) NA else e20$n.dim
ari  <- if(is.null(e20)) NA else {
  mem <- e20$wc; names(mem) <- colnames(X20)
  round(mclust::adjustedRandIndex(mem[map20$final_col], apriori), 3)
}
cat(sprintf("EGA 2020: %s communities; ARI vs a-priori principles = %s\n", ndim, ari))

# --- append to manifest (replace tier3 keys only) ---
man <- file.path(TAB,"08_cisla.csv")
m <- read.csv(man, stringsAsFactors=FALSE)
keys <- c("framework","tier3_status","n_2020_complete","tier3_n_items","tier3_items_per_principle",
          "congruence_2020_min","congruence_2020_mean","ega_2020_ndim","ari_2020_apriori",
          "congruence_2020_by_factor")
m <- m[!m$metric %in% keys, ]
add <- data.frame(metric=keys, value=c(
  "three-tier: T1{2023,2024,2026} invariance+means; T2{2021,2022} structure only; T3{2020} configural EFA+EGA on author-confirmed links",
  "DONE: 6 pairings author-confirmed 2026-07-11; configural EFA+EGA on 12 aligned items",
  nrow(X20), nrow(map20),
  paste(names(table(map20$principle)), table(map20$principle), sep="=", collapse=", "),
  round(min(cg20),3), round(mean(cg20),3), ndim, ari,
  paste(sprintf("%s=%.3f", names(cg20), cg20), collapse="; ")))
write.csv(rbind(m, add), man, row.names=FALSE)
cat("appended tier3 metrics to 08_cisla.csv\n")
