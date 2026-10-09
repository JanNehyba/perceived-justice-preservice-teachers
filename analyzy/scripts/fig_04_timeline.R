#!/usr/bin/env Rscript
# Figure 4.1 — výzkum na časové ose: dva proudy, kohortové roky 2019-2026,
# tři stupně srovnatelnosti, hranice škály 2022|2023. Nahrazuje dřívější graphviz
# verzi (Janova výtka: "měl by tam být naznačený vývoj"). Manuál: kniha/GRAFICKY-MANUAL.md.
# Velikosti vzorků se čtou z manifestů čísel (vystupy/tabulky/*_cisla.csv), nikdy natvrdo
# (revize 8. 10. 2026: dřívější natvrdo zapsané „viněty n = 146" neodpovídalo datům, n = 315).
# Výstup: 04_tri_stupne-cs.png/.pdf (kniha, česky) a 04_tri_stupne.png/.pdf (anglicky, companion).
suppressPackageStartupMessages({library(ggplot2); library(dplyr)})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts", "scripts"))[1]
source(file.path(SCR, "theme_book.R"))
FIG <- normalizePath(file.path(SCR, "..", "..", "vystupy", "obrazky"))
TAB <- normalizePath(file.path(SCR, "..", "..", "vystupy", "tabulky"))

man <- function(file, key) {
  m <- read.csv(file.path(TAB, file), colClasses = "character")
  v <- m$value[m$metric == key]
  if (length(v) != 1) stop("manifest ", file, ": klíč ", key, " chybí")
  v
}
N <- list(
  vinety = man("05_cisla.csv", "n_total"),
  y2020  = man("08_cisla.csv", "n_2020"),
  y2021  = man("06_cisla.csv", "n_2021_pool36_raw"),
  y2022  = man("08_cisla.csv", "n_2022"),
  y2023  = man("07_cisla.csv", "n_2023"),
  y2024  = man("07_cisla.csv", "n_2024"),
  y2026  = man("07_cisla.csv", "n_2026"),
  pooled = man("07_cisla.csv", "n_total")
)

TXT <- list(
  en = list(
    coh = c(
      "2019\npilot\nversion 1",
      sprintf("2020\nn = %s\npilot\nversion 2", N$y2020),
      sprintf("2021\nn = %s\nitem\npool", N$y2021),
      sprintf("2022\nn = %s\n26 items\n+ BIDR", N$y2022),
      sprintf("2023\nn = %s\nfinal instrument", N$y2023),
      sprintf("2024\nn = %s\nfinal instrument", N$y2024),
      sprintf("2026\nn = %s\nfinal instrument", N$y2026)),
    bands = c("TIER 3\nconfigural only", "TIER 2\nstructure only",
              "TIER 1\nfull invariance + latent means"),
    boundary = "SCALE BOUNDARY:  agreement -> fairness",
    vign = sprintf("Six-villages vignettes\nspring 2019, n = %s", N$vinety),
    stream = "Separate judgement study (Study 1);\nnot pooled with the questionnaire stream",
    pooled = sprintf("pooled n = %s (Study 3)", N$pooled),
    out = "04_tri_stupne.png"),
  cs = list(
    coh = c(
      "2019\npilotní\nverze 1",
      sprintf("2020\nn = %s\npilotní\nverze 2", N$y2020),
      sprintf("2021\nn = %s\nzásobník\npoložek", N$y2021),
      sprintf("2022\nn = %s\n26 položek\n+ BIDR", N$y2022),
      sprintf("2023\nn = %s\nfinální nástroj", N$y2023),
      sprintf("2024\nn = %s\nfinální nástroj", N$y2024),
      sprintf("2026\nn = %s\nfinální nástroj", N$y2026)),
    bands = c("STUPEŇ 3\njen konfigurální srovnání", "STUPEŇ 2\njen struktura",
              "STUPEŇ 1\nplná invariance + latentní průměry"),
    boundary = "HRANICE ŠKÁLY:  souhlas -> spravedlnost",
    vign = sprintf("Viněty šesti vesnic\njaro 2019, n = %s", N$vinety),
    stream = "Samostatná studie posuzování vinět (studie 1);\ndata se s dotazníkovým proudem neslučují",
    pooled = sprintf("sloučeno n = %s (studie 3)", N$pooled),
    out = "04_tri_stupne-cs.png")
)

make_fig <- function(L) {
  coh <- tibble::tibble(year = c(2019:2024, 2026), label = L$coh,
                        tier = c("doc", "tier3", "tier2", "tier2", "tier1", "tier1", "tier1"))
  coh$fill <- c(doc = "#FFFFFF", tier3 = GREY_FILL, tier2 = "#FFD9B8",
                tier1 = MUNI_BLUE)[coh$tier]
  coh$txt  <- ifelse(coh$tier == "tier1", "white", "black")
  bands <- tibble::tibble(xmin = c(2019.62, 2020.62, 2022.62),
                          xmax = c(2020.38, 2022.42, 2026.45),
                          lab = L$bands, col = c(GREY_FILL, "#FFD9B8", "#D6DBF8"))
  QY <- 1; VY <- 2.05                    # řádky proudů
  ggplot() +
    geom_rect(data = bands, aes(xmin = xmin, xmax = xmax),
              ymin = QY - 0.42, ymax = QY + 0.42, fill = bands$col, alpha = .45) +
    geom_text(data = bands, aes(x = (xmin + xmax) / 2, label = lab),
              y = QY + 0.58, size = 3.6, fontface = "bold", color = "black",
              lineheight = .95) +
    annotate("segment", x = 2018.75, xend = 2026.65, y = 0.28, yend = 0.28,
             arrow = arrow(length = unit(6, "pt"), type = "closed"),
             color = "black", linewidth = .5) +
    annotate("text", x = c(2019:2024, 2026), y = 0.17,
             label = c(2019:2024, 2026), size = 3.8, color = "black") +
    annotate("segment", x = 2022.52, xend = 2022.52, y = 0.30, yend = 2.42,
             linetype = "dashed", color = MU_RED, linewidth = .7) +
    annotate("text", x = 2022.52, y = 2.55, label = L$boundary,
             color = MU_RED, size = 3.8, fontface = "bold") +
    geom_label(aes(x = 2018.85, y = VY), label = L$vign,
               fill = "white", color = MU_GREEN, label.size = .8, hjust = 0,
               size = 3.6, lineheight = .95, fontface = "bold") +
    annotate("text", x = 2022.75, y = VY, hjust = 0, size = 3.5, color = GREY_TEXT,
             label = L$stream) +
    geom_label(data = coh, aes(x = year, y = QY, label = label),
               fill = coh$fill, colour = coh$txt, size = 3.0, lineheight = .92,
               label.size = .45, label.padding = unit(.18, "lines"),
               label.r = unit(.12, "lines")) +
    annotate("segment", x = 2022.7, xend = 2026.35, y = QY - 0.52, yend = QY - 0.52,
             color = MUNI_BLUE, linewidth = .8) +
    annotate("text", x = 2024.5, y = QY - 0.66, color = MUNI_BLUE, size = 3.6,
             fontface = "bold", label = L$pooled) +
    scale_x_continuous(limits = c(2018.45, 2027.15), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0.05, 2.75), expand = c(0, 0)) +
    theme_book() +
    theme(axis.text = element_blank(), axis.title = element_blank(),
          panel.grid = element_blank())
}

for (lang in names(TXT)) {
  out <- file.path(FIG, TXT[[lang]]$out)
  save_book_fig(out, make_fig(TXT[[lang]]), width = 9.2, height = 5.2)
  cat("written:", out, "\n")
}
