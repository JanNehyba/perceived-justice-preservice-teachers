#!/usr/bin/env Rscript
# Figure 4.1 — výzkumný program jako TIMELINE: dva proudy, kohortové roky 2019-2026,
# tři tiery srovnatelnosti, hranice škály 2022|2023. Nahrazuje dřívější graphviz
# verzi (Janova výtka: "měl by tam být naznačený vývoj"). Manuál: kniha/GRAFICKY-MANUAL.md.
# n's: DATA_README (2020=375, 2021=433 sběr/346 analytické, 2022=263, 2023=247,
# 2024=333, 2026=164; viněty 2019 n=146).
suppressPackageStartupMessages({library(ggplot2); library(dplyr)})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts"))[1]
source(file.path(SCR, "theme_book.R"))
FIG <- normalizePath(file.path(SCR, "..", "..", "vystupy", "obrazky"))

coh <- tibble::tribble(
  ~year, ~label,                      ~tier,
  2019,  "2019\nwording only",        "doc",
  2020,  "2020\nn = 375\n3rd-person normative", "tier3",
  2021,  "2021\nn = 433\n1st-person pool",      "tier2",
  2022,  "2022\nn = 263\n26 items + BIDR",      "tier2",
  2023,  "2023\nn = 247\nfinal instrument",     "tier1",
  2024,  "2024\nn = 333\nfinal instrument",     "tier1",
  2026,  "2026\nn = 164\nfinal instrument",     "tier1"
)
coh$fill <- c(doc = "#FFFFFF", tier3 = GREY_FILL, tier2 = "#FFD9B8",
              tier1 = MUNI_BLUE)[coh$tier]
coh$txt  <- ifelse(coh$tier == "tier1", "white", "black")
coh$bord <- c(doc = GREY_LINE, tier3 = GREY_LINE, tier2 = PED_ORANGE,
              tier1 = MUNI_BLUE)[coh$tier]

bands <- tibble::tribble(
  ~xmin, ~xmax, ~lab, ~col,
  2019.62, 2020.38, "TIER 3\nconfigural only",              GREY_FILL,
  2020.62, 2022.42, "TIER 2\nstructure only",               "#FFD9B8",
  2022.62, 2026.45, "TIER 1\nfull invariance + latent means", "#D6DBF8"
)

QY <- 1; VY <- 2.05                    # řádky proudů
p <- ggplot() +
  # tier pásy za dotazníkovým proudem
  geom_rect(data = bands, aes(xmin = xmin, xmax = xmax),
            ymin = QY - 0.42, ymax = QY + 0.42, fill = bands$col, alpha = .45) +
  geom_text(data = bands, aes(x = (xmin + xmax) / 2, label = lab),
            y = QY + 0.56, size = 3.1, fontface = "bold", color = "black",
            lineheight = .95) +
  # časová osa
  annotate("segment", x = 2018.75, xend = 2026.65, y = 0.28, yend = 0.28,
           arrow = arrow(length = unit(6, "pt"), type = "closed"),
           color = "black", linewidth = .5) +
  annotate("text", x = c(2019:2024, 2026), y = 0.17,
           label = c(2019:2024, 2026), size = 3.4, color = "black") +
  # hranice škály
  annotate("segment", x = 2022.52, xend = 2022.52, y = 0.30, yend = 2.42,
           linetype = "dashed", color = MU_RED, linewidth = .7) +
  annotate("text", x = 2022.52, y = 2.55,
           label = "SCALE BOUNDARY:  agreement -> fairness",
           color = MU_RED, size = 3.3, fontface = "bold") +
  # vinětový proud (jednorázový, jaro 2019)
  geom_label(aes(x = 2018.85, y = VY),
             label = "Six-villages vignettes\nspring 2019, n = 146",
             fill = "white", color = MU_GREEN, label.size = .8, hjust = 0,
             size = 3.2, lineheight = .95, fontface = "bold") +
  annotate("text", x = 2021.05, y = VY, hjust = 0, size = 3.1, color = GREY_TEXT,
           label = "Stream 2 — one-off judgement study (Study 1);\nnever pooled with the questionnaire stream") +
  # dotazníkový proud
  geom_label(data = coh, aes(x = year, y = QY, label = label),
             fill = coh$fill, colour = coh$txt, size = 2.9, lineheight = .95,
             label.size = .45, label.padding = unit(.18, "lines"),
             label.r = unit(.12, "lines")) +
  # pooled svorka pod tier 1
  annotate("segment", x = 2022.7, xend = 2026.35, y = QY - 0.52, yend = QY - 0.52,
           color = MUNI_BLUE, linewidth = .8) +
  annotate("text", x = 2024.5, y = QY - 0.66, color = MUNI_BLUE, size = 3.2,
           fontface = "bold", label = "pooled n = 744 (Study 3)") +
  scale_x_continuous(limits = c(2018.7, 2027.15), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0.05, 2.75), expand = c(0, 0)) +
  theme_book() +
  theme(axis.text = element_blank(), axis.title = element_blank(),
        panel.grid = element_blank())

save_book_fig(file.path(FIG, "04_tri_stupne.png"), p, width = 10.4, height = 4.6)
cat("written:", file.path(FIG, "04_tri_stupne.png"), "\n")
