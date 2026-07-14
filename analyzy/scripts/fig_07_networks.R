#!/usr/bin/env Rscript
# Figury kap. 7 v jednotném stylu (kniha/GRAFICKY-MANUAL.md):
#  - 07_network_dvoupanel.png  (Figure 7.1): tatáž pooled síť dvakrát — A: a priori
#    principy (fixní barvy), B: EGA komunity. Stejná estimace jako 30_network.qmd
#    (EBICglasso, cor_auto, gamma=.5, n=744).
#  - 07_network_tripanel.png   (Figure 7.2 NOVÁ): sítě kohort 2023 | 2024 | 2026 se
#    SPOLEČNÝM averageLayout — vizuální protějšek NCT nulových rozdílů (7.4.4).
# Žádná nová čísla: figury jen zobrazují; všechny statistiky zůstávají zmražené.
suppressPackageStartupMessages({library(bootnet); library(qgraph); library(EGAnet)})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts"))[1]
ROOT <- normalizePath(file.path(SCR, "..", ".."))
FIG <- file.path(ROOT, "vystupy", "obrazky")

# Jazyk figur: `Rscript fig_07_networks.R cs` -> ceske popisky + soubory *-cs.png.
# Default (bez argumentu) = EN, chovani beze zmeny. Estimace/cisla identicka.
ARGS <- commandArgs(trailingOnly = TRUE)
FIG_LANG <- if (length(ARGS) >= 1) ARGS[1] else "en"
SUF <- if (FIG_LANG == "cs") "-cs" else ""

MUNI_BLUE <- "#0000DC"; PED_ORANGE <- "#FF7300"; MU_GREEN <- "#00AF3F"
MU_PURPLE <- "#9100DC"; MU_RED <- "#F01928"; MU_YELLOW <- "#FFD200"
if (FIG_LANG == "cs") {
  GRP <- c("Procedurální", "Rovnost", "Potřeby", "Zásluhy")
  T_A <- "A: apriorní principy"; T_B <- "B: komunity EGA"
} else {
  GRP <- c("Procedural", "Equality", "Needs", "Merit")
  T_A <- "A: a priori principles"; T_B <- "B: EGA communities"
}
PAL <- setNames(c(MUNI_BLUE, PED_ORANGE, MU_GREEN, MU_PURPLE), GRP)

d <- read.csv(file.path(ROOT, "data", "processed", "justice_final.csv"))
items <- sprintf("item_%02d", 1:26)
X <- d[, items]

MAP <- list(c(1,2,6,7,8,23,24,26), c(3,10,14,15,16,22),
            c(4,5,9,11,17,18), c(12,13,19,20,21,25))
names(MAP) <- GRP
apriori <- integer(26); for (k in seq_along(MAP)) apriori[MAP[[k]]] <- k
groups_ap <- factor(names(MAP)[apriori], levels = names(MAP))

net <- estimateNetwork(X, default = "EBICglasso", corMethod = "cor_auto", tuning = 0.5)
W <- net$graph
avg_layout <- qgraph::averageLayout(W)

# EGA komunity (walktrap, jako v notebooku)
ega <- EGA(X, model = "glasso", algorithm = "walktrap", plot.EGA = FALSE)
groups_ega <- factor(paste0("EGA-", ega$wc))
pal_ega <- c(MUNI_BLUE, PED_ORANGE, MU_GREEN, MU_PURPLE, MU_RED, MU_YELLOW)

# --- Figure 7.1: dvoupanel ---------------------------------------------------
png(file.path(FIG, paste0("07_network_dvoupanel", SUF, ".png")),
    width = 3200, height = 1600, res = 300)
par(mfrow = c(1, 2), family = "Arial")
qgraph(W, layout = avg_layout, groups = groups_ap, color = unname(PAL),
       labels = 1:26, title = T_A, title.cex = 1.1,
       legend.cex = .38, vsize = 6, border.width = 1.5, border.color = "white",
       edge.color = NULL, posCol = "#5A5AE8", negCol = MU_RED)
qgraph(W, layout = avg_layout, groups = groups_ega,
       color = pal_ega[seq_len(nlevels(groups_ega))],
       labels = 1:26, title = T_B, title.cex = 1.1,
       legend.cex = .38, vsize = 6, border.width = 1.5, border.color = "white",
       posCol = "#5A5AE8", negCol = MU_RED)
dev.off()

# --- Figure 7.2 (NOVÁ): trojpanel kohort se společným layoutem ---------------
waves <- as.character(sort(unique(d$wave)))
d$wave <- as.character(d$wave)
nets_w <- lapply(waves, function(w)
  estimateNetwork(d[d$wave == w, items], default = "EBICglasso",
                  corMethod = "cor_auto", tuning = 0.5))
names(nets_w) <- waves
lay3 <- qgraph::averageLayout(lapply(nets_w, function(n) n$graph))

png(file.path(FIG, paste0("07_network_tripanel", SUF, ".png")),
    width = 3900, height = 1400, res = 300)
par(mfrow = c(1, 3), family = "Arial")
for (w in waves) {
  nn <- sum(d$wave == w)
  qgraph(nets_w[[w]]$graph, layout = lay3, groups = groups_ap,
         color = unname(PAL), labels = 1:26,
         title = paste0(w, "  (n = ", nn, ")"), title.cex = 1.3,
         legend = (w == waves[length(waves)]), legend.cex = .38,
         vsize = 6.5, border.width = 1.5, border.color = "white",
         posCol = "#5A5AE8", negCol = MU_RED)
}
dev.off()
cat(sprintf("written: 07_network_dvoupanel%s.png + 07_network_tripanel%s.png\n", SUF, SUF))
