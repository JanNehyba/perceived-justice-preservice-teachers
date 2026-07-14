#!/usr/bin/env Rscript
# Figury 5.1 (likert rozložení) a 5.2 (klastrové profily) v jednotném stylu knihy
# (kniha/GRAFICKY-MANUAL.md): divergentní škála 1-7 oranžová->šedá->MUNI modrá,
# barvy vesnic = jejich jména. Data: vinety_final.csv (n=315) — deskriptivní
# rozložení; klastrové PROFILY čtou ZMRAZENÝ výstup 05_vinety_cluster_profiles.csv
# (žádný přepočet modelů).
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(tidyr)})
SCR <- Filter(dir.exists, c("../scripts", "analyzy/scripts"))[1]
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
           v_kasty="Kasty (žlutá)")
  L_RATING <- "Hodnocení\n(1 = zcela nespravedlivé,\n7 = zcela spravedlivé)"
  L_PCT    <- "Procento respondentů"
  L_MEAN   <- "Průměrné hodnocení (1–7)"
  L_CLUST  <- "Skupina "
  L_NEED_X <- "Hodnocení vesnice potřeb (1 = zcela nespravedlivé … 7 = zcela spravedlivé)"
  L_NEED_Y <- "Počet respondentů"
  L_PROF   <- c("need-inclusive" = "inkluzivní vůči potřebám",
                "equality-first / need-skeptical" = "rovnost první / skeptičtí k potřebám")
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

# --- Figure 5.2: klastrové profily (zmrazené) --------------------------------
prof <- read.csv(file.path(TAB, "05_vinety_cluster_profiles.csv"),
                 check.names = FALSE)
pcols <- setdiff(names(prof), c("cluster", "n"))
# klice = anglicke hodnoty ve zmrazenem CSV; zobrazene popisky dle FIG_LANG (pres LAB)
vil_key <- c(Equality = "v_rovnost", Chance = "v_nahoda", Need = "v_potreby",
             Merit = "v_zasluhy", `Equal opportunity` = "v_rovne_prilezitosti",
             Caste = "v_kasty")
vil_lab <- setNames(LAB[vil_key], names(vil_key))
lev <- unname(LAB[ord])
prof_long <- prof %>%
  pivot_longer(all_of(pcols), names_to = "principle", values_to = "mean") %>%
  mutate(principle = factor(vil_lab[principle], levels = lev),
         cluster = paste0(L_CLUST, cluster, " (n = ", n, ")"))

pal_cl <- c(MUNI_BLUE, PED_ORANGE, "#6E6E6E")
p2 <- ggplot(prof_long, aes(principle, mean, group = cluster, color = cluster)) +
  geom_line(linewidth = 1) + geom_point(size = 2.2) +
  scale_color_manual(values = pal_cl[seq_len(nrow(prof))], name = NULL) +
  scale_y_continuous(limits = c(1, 7), breaks = 1:7) +
  labs(x = NULL, y = L_MEAN) +
  theme_book() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1),
        legend.position = "top")
save_book_fig(file.path(FIG, paste0("05_vinety_clusters", SUF, ".png")), p2, width = 8.6, height = 5)

# --- Figure 5.3: the need-acceptance axis (one hump, split into the two profiles) ---
# Shows that the k=2 "typology" is a single continuous distribution of Need ratings
# cut through the middle, not two separated clusters.
memb <- read.csv(file.path(TAB, "05_vinety_cluster_membership.csv"), check.names = FALSE)
memb$profile <- factor(memb$profile,
  levels = c("need-inclusive", "equality-first / need-skeptical"))
need_df <- memb %>% count(need, profile)
p3 <- ggplot(need_df, aes(factor(need), n, fill = profile)) +
  geom_col(width = 0.82, color = "white", linewidth = .2) +
  scale_fill_manual(values = c("need-inclusive" = MUNI_BLUE,
                               "equality-first / need-skeptical" = PED_ORANGE),
                    labels = L_PROF, name = NULL) +
  labs(x = L_NEED_X, y = L_NEED_Y) +
  theme_book() +
  theme(legend.position = "top", panel.grid.major.x = element_blank())
save_book_fig(file.path(FIG, paste0("05_vinety_need_axis", SUF, ".png")), p3, width = 8.6, height = 4.6)
cat(sprintf("written: 05_vinety_likert%s.png + 05_vinety_clusters%s.png + 05_vinety_need_axis%s.png\n",
            SUF, SUF, SUF))
