#!/usr/bin/env Rscript
# Figury typologie (kap. 2.7 + Příloha E) — jednotný styl (kniha/GRAFICKY-MANUAL.md).
#  Figure 2.2  = 02_dendrogram_hlavni.png : ČITELNÝ Ward dendrogram 24 konceptů
#                (nahrazuje nečitelný NeighborNet v kapitole; Janova výtka).
#  Figure E.1  = E5_embed_dendrogram.png : embeddingový strom (druhý pohled).
#  Figure E.2  = E5_tanglegram.png : tanglegram obou stromů.
# Vstup = ZMRAZENÁ konsensuální matice E5_consensus_matrix.csv (žádný přepočet kódování).
suppressPackageStartupMessages({
  library(cluster); library(dendextend)
})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts"))[1]
ROOT <- normalizePath(file.path(SCR, "..", ".."))
FIG  <- file.path(ROOT, "vystupy", "obrazky")
PROC <- file.path(ROOT, "data", "processed")
TAB  <- file.path(ROOT, "vystupy", "tabulky")

# Barvoslepe bezpecna paleta pro ctyri DATOVE skupiny (Okabe-Ito).
# Cisla skupin jsou lokalni identifikatory rezu stromu, nikoli teoreticke rodiny.
PAL_CLUSTER <- c(`1`="#0072B2", `2`="#E69F00", `3`="#009E73", `4`="#CC79A7")
LTY_CLUSTER <- c(`1`=1, `2`=2, `3`=3, `4`=4)
MEASURED <- c("Procedural justice", "Equality", "Need", "Merit/desert (equity)")

# Jazyk figur: `Rscript fig_E5_trees.R cs` -> ceske popisky + soubory *-cs.png.
# Default (bez argumentu) = EN. Vypocty (Gower/Ward) identicke; meni se jen popisky.
ARGS <- commandArgs(trailingOnly = TRUE)
FIG_LANG <- if (length(ARGS) >= 1) ARGS[1] else "en"
SUF <- if (FIG_LANG == "cs") "-cs" else ""
# ceske nazvy 24 konceptu = doslova dle kapitoly/cs/appendix-E (E.1), kapitalizovane
TAXON_CS <- c(
  "Equality" = "Rovnost", "Need" = "Potřeby",
  "Merit/desert (equity)" = "Zásluhy (ekvita)",
  "Difference principle" = "Princip diference", "Sufficiency" = "Dostatečnost",
  "Fair equality of opportunity" = "Spravedlivá rovnost příležitostí",
  "Luck egalitarianism" = "Egalitarismus štěstí",
  "Capabilities approach" = "Přístup schopností",
  "Procedural justice" = "Procedurální spravedlnost",
  "Interpersonal justice" = "Interpersonální spravedlnost",
  "Informational justice" = "Informativní spravedlnost",
  "Retributive justice" = "Retributivní spravedlnost",
  "Restorative justice" = "Restorativní spravedlnost",
  "Corrective (rectificatory) justice" = "Korektivní (rektifikační) spravedlnost",
  "Compensatory justice" = "Kompenzační spravedlnost",
  "Social justice" = "Sociální spravedlnost",
  "Commutative justice" = "Komutativní spravedlnost",
  "Justice as fairness" = "Spravedlnost jako férovost",
  "Complex equality (spheres)" = "Komplexní rovnost (sféry)",
  "Recognition justice" = "Spravedlnost uznání",
  "Relational equality" = "Relační rovnost",
  "Entitlement (libertarian) justice" = "Nároková (libertariánská) spravedlnost",
  "Utilitarian justice" = "Utilitaristická spravedlnost",
  "Formal justice (impartiality)" = "Formální spravedlnost (nestrannost)")
if (FIG_LANG == "cs") {
  L_CLUSTER <- paste("skupina", 1:4)
  L_CLUSTERTITLE <- "Explorativní řez stromu (k = 4)"
  L_MEASURED <- "princip měřený knihou"
  L_XGOWER <- "Konceptuální vzdálenost (Gower, Wardovo spojování)"
  L_XEMBED <- "Sémantická vzdálenost (embeddingy definic, Wardovo spojování)"
  L_TL <- "znakové kódování"; L_TR <- "embeddingy"
  # delší česká jména (až 38 znaků) potřebují širší vnitřní okraj a menší písmo,
  # jinak se v tanglegramu ořezávají (Korektivní…, Nároková…, Formální…)
  MAR_R <- 13.5; TG_MARGIN <- 16; TG_CEX <- 0.82
} else {
  L_CLUSTER <- paste("cluster", 1:4)
  L_CLUSTERTITLE <- "Exploratory tree cut (k = 4)"
  L_MEASURED <- "principle measured in the book"
  L_XGOWER <- "Conceptual distance (Gower, Ward linkage)"
  L_XEMBED <- "Semantic distance (definition embeddings, Ward linkage)"
  L_TL <- "character-coded"; L_TR <- "embedding"
  MAR_R <- 12; TG_MARGIN <- 11; TG_CEX <- 0.95
}
# Popisky jsou vsechny cerne. Ctyri merene pojmy rozlisuje tvar + tucne pismo,
# aby se jejich vyznaceni nepletlo s barvou datove ziskanych vetvi.
style_labels <- function(d) {
  original <- labels(d)
  is_measured <- original %in% MEASURED
  display <- if (FIG_LANG == "cs") unname(TAXON_CS[original]) else original
  labels(d) <- display
  labels_colors(d) <- rep("#1A1A1A", length(display))
  d <- assign_values_to_leaves_nodePar(d, ifelse(is_measured, 2, 1), "lab.font")
  d <- assign_values_to_leaves_nodePar(d, ifelse(is_measured, 18, NA), "pch")
  d <- assign_values_to_leaves_nodePar(d, ifelse(is_measured, 0.9, NA), "cex")
  d <- assign_values_to_leaves_nodePar(d, rep("#1A1A1A", length(display)), "col")
  d
}

cons <- read.csv(file.path(TAB, "E5_consensus_matrix.csv"),
                 stringsAsFactors = FALSE, check.names = FALSE)
rownames(cons) <- cons$taxon
CH <- setdiff(names(cons), "taxon")
W <- cons[, CH]; W[] <- lapply(W, factor)
D <- cluster::daisy(W, metric = "gower")
hc <- hclust(D, method = "ward.D2")
cl4 <- stats::cutree(hc, k = 4)

# --- Figure 2.2: čitelný horizontální dendrogram -----------------------------
dend <- as.dendrogram(hc)
dend <- set(dend, "labels_cex", 0.95)
dend <- set(dend, "branches_lwd", 2)
cl_leaf <- cl4[labels(dend)]
dend <- branches_attr_by_clusters(
  dend, cl_leaf, values = unname(PAL_CLUSTER[as.character(cl_leaf)]), attr = "col"
)
dend <- branches_attr_by_clusters(
  dend, cl_leaf, values = unname(LTY_CLUSTER[as.character(cl_leaf)]), attr = "lty"
)
dend <- style_labels(dend)

png(file.path(FIG, paste0("02_dendrogram_hlavni", SUF, ".png")),
    width = 2600, height = 2400, res = 300)
par(mar = c(4, 1, 1, MAR_R), family = "Helvetica")
plot(dend, horiz = TRUE, xlab = L_XGOWER)
legend("topleft", legend = c(L_CLUSTER, L_MEASURED),
       col = c(unname(PAL_CLUSTER), "#1A1A1A"),
       lty = c(unname(LTY_CLUSTER), NA), lwd = c(rep(3, 4), NA),
       pch = c(rep(NA, 4), 18), bty = "n", cex = 0.9,
       title = L_CLUSTERTITLE, title.col = "black")
dev.off()
cat(sprintf("written: 02_dendrogram_hlavni%s.png\n", SUF))

# NeighborNet se do knihy NEDÁVÁ (nečitelný — Janův pokyn 12. 7. 2026).
# Obě srovnávané reprezentace používají čitelné Wardovy dendrogramy.

# --- Figure E.1: embeddingový dendrogram (druhý, znakově-nezávislý pohled) -----
# Ward strom z EMBEDDING vzdáleností (typology_embed_dist.csv) — stejný čitelný styl
# jako hlavní dendrogram (Fig 2.2), aby šly oba pohledy přímo porovnat.
E <- read.csv(file.path(PROC, "typology_embed_dist.csv"), row.names = 1,
              check.names = FALSE)
Ee <- as.dist(as.matrix(E))
hce <- hclust(Ee, method = "ward.D2")
dend_e <- as.dendrogram(hce)
dend_e <- set(dend_e, "labels_cex", 0.95)
dend_e <- set(dend_e, "branches_lwd", 2)
dend_e <- set(dend_e, "branches_col", "#3D3D3D")
dend_e <- style_labels(dend_e)
png(file.path(FIG, paste0("E5_embed_dendrogram", SUF, ".png")),
    width = 2600, height = 2400, res = 300)
par(mar = c(4, 1, 1, MAR_R), family = "Helvetica")
plot(dend_e, horiz = TRUE, xlab = L_XEMBED)
legend("topleft", legend = L_MEASURED, col = "#1A1A1A", pch = 18,
       bty = "n", cex = 0.9)
dev.off()
cat(sprintf("written: E5_embed_dendrogram%s.png (dendrogram, čitelný)\n", SUF))

# --- Figure E.2: tanglegram — dva pohledy vedle sebe, čitelně -----------------
# Sladíme listy obou stromů a spojíme neutralnimi carami. Velke pismo.
common <- intersect(labels(hc), labels(hce))
dcc <- as.dendrogram(hclust(as.dist(as.matrix(daisy(W, "gower"))[common, common]), "ward.D2"))
dee <- as.dendrogram(hclust(as.dist(as.matrix(E)[common, common]), "ward.D2"))
dcc <- set(dcc, "branches_col", "#3D3D3D")
dee <- set(dee, "branches_col", "#3D3D3D")
dcc <- style_labels(dcc); dee <- style_labels(dee)   # shodne prejmenovani obou stromu
dl <- dendlist(dcc, dee) |> untangle(method = "step2side")
png(file.path(FIG, paste0("E5_tanglegram", SUF, ".png")),
    width = 3200, height = 2600, res = 300)
par(family = "Helvetica")
tanglegram(dl, common_subtrees_color_branches = FALSE,
           color_lines = rep("#A0A0A0", length(common)), lwd = 2,
           lab.cex = TG_CEX, edge.lwd = 2,
           margin_inner = TG_MARGIN, main_left = L_TL,
           main_right = L_TR, cex_main = 1.1,
           columns_width = c(5, 2, 5))
dev.off()
cat(sprintf("written: E5_tanglegram%s.png (čitelný)\n", SUF))
# starý nečitelný NeighborNet odstraníme, ať se omylem nevloží
for (f in c("E5_neighbornet.png"))
  if (file.exists(file.path(FIG, f))) file.remove(file.path(FIG, f))
