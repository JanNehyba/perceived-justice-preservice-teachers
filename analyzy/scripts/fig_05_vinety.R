#!/usr/bin/env Rscript
# Figura 5.1 (likertovské rozložení hodnocení) v jednotném stylu knihy
# (kniha/GRAFICKY-MANUAL.md): divergentní škála 1-7 oranžová->šedá->MUNI modrá,
# barvy vesnic = jejich jména. Data: vinety_final.csv (n=315), deskriptivní rozložení.
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(tidyr)})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts", "scripts"))[1]
source(file.path(SCR, "theme_book.R"))
ROOT <- normalizePath(file.path(SCR, "..", ".."))
FIG <- file.path(ROOT, "vystupy", "obrazky")
TAB <- file.path(ROOT, "vystupy", "tabulky")

# Jazyk figur: `Rscript fig_05_vinety.R cs` -> ceske popisky + soubory *-cs.png.
# Default (bez argumentu) = EN, chovani beze zmeny. Cisla/data identicka v obou jazycich.
ARGS <- commandArgs(trailingOnly = TRUE)
FIG_LANG <- if (length(ARGS) >= 1) ARGS[1] else "en"
SUF <- if (FIG_LANG == "cs") "-cs" else ""

V   <- c("v_rovnost","v_nahoda","v_potreby","v_zasluhy","v_rovne_prilezitosti","v_kasty")
if (FIG_LANG == "cs") {
  LAB <- c(v_rovnost="Rovnost (modrá)", v_nahoda="Náhoda (bílá)", v_potreby="Potřeby (zelená)",
           v_zasluhy="Zásluhy (oranžová)", v_rovne_prilezitosti="Rovné příležitosti (červená)",
           v_kasty="Společenské skupiny (žlutá)")
  L_RATING <- "Hodnocení\n(1 = naprosto nespravedlivě,\n7 = naprosto spravedlivě)"
  L_PCT    <- "Procento respondentů"
  L_MEAN   <- "Průměrné hodnocení (1–7)"
  L_CLUST  <- "Skupina "
  L_NEED_X <- "Hodnocení vesnice potřeb (1 = naprosto nespravedlivě … 7 = naprosto spravedlivě)"
  L_NEED_Y <- "Počet respondentů"
  L_PROF   <- c("need-inclusive" = "vyšší přijetí potřeb",
                "equality-first / need-skeptical" = "nižší přijetí potřeb")
} else {
  LAB <- c(v_rovnost="Equality (Blue)", v_nahoda="Chance (White)", v_potreby="Need (Green)",
           v_zasluhy="Merit (Orange)", v_rovne_prilezitosti="Equal opportunity (Red)",
           v_kasty="Caste (Yellow)")
  L_RATING <- "Rating\n(1 = completely unjust,\n7 = completely just)"
  L_PCT    <- "Percentage of respondents"
  L_MEAN   <- "Mean rating (1–7)"
  L_CLUST  <- "Cluster "
  L_NEED_X <- "Rating of the Need village (1 = completely unjust … 7 = completely just)"
  L_NEED_Y <- "Number of respondents"
  L_PROF   <- c("need-inclusive" = "need-inclusive",
                "equality-first / need-skeptical" = "equality-first / need-skeptical")
}

d <- read.csv(file.path(ROOT, "data", "processed", "vinety_final.csv"))
ord <- names(sort(sapply(d[V], mean, na.rm = TRUE), decreasing = TRUE))  # dle průměru

# --- Figure 5.1: likert stacked ---------------------------------------------
likert_df <- d %>%
  select(all_of(V)) %>%
  pivot_longer(everything(), names_to = "var", values_to = "score") %>%
  filter(!is.na(score)) %>%
  count(var, score) %>%
  group_by(var) %>% mutate(pct = n / sum(n) * 100) %>% ungroup() %>%
  mutate(principle = factor(LAB[var], levels = rev(LAB[ord])),
         score = factor(score, levels = 1:7))

p1 <- ggplot(likert_df, aes(principle, pct, fill = score)) +
  geom_col(width = 0.7, color = "white", linewidth = .2) +
  coord_flip() +
  scale_fill_manual(values = BOOK_DIVERGING7, name = L_RATING) +
  labs(x = NULL, y = L_PCT) +
  theme_book() +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(color = GREY_FILL),
        legend.position = "right")
save_book_fig(file.path(FIG, paste0("05_vinety_likert", SUF, ".png")), p1, width = 9, height = 4.6)

# Figury 5.2 (klastrové profily) a 5.3 (osa přijetí potřeb) byly 9. 10. 2026 z knihy odstraněny:
# zobrazovaly dvouskupinové řešení, které z dat a kódu nelze reprodukovat (viz 10_vinety.qmd, oddíl 6).
cat(sprintf("written: 05_vinety_likert%s.png\n", SUF))
