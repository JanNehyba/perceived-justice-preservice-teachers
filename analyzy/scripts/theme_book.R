# Jednotné téma a palety figur knihy — implementace kniha/GRAFICKY-MANUAL.md.
# Použití v každém figure-skriptu/notebooku: source("../scripts/theme_book.R")
# (cesty řeší Filter(dir.exists, ...) vzor jako jinde v projektu).

suppressPackageStartupMessages(library(ggplot2))

# --- barvy MU / PdF (brandcloud) ------------------------------------------
MUNI_BLUE   <- "#0000DC"
PED_ORANGE  <- "#FF7300"
MU_GREEN    <- "#00AF3F"
MU_PURPLE   <- "#9100DC"
MU_RED      <- "#F01928"
MU_YELLOW   <- "#FFD200"
GREY_TEXT   <- "#6E6E6E"
GREY_LINE   <- "#B8B8B8"
GREY_FILL   <- "#EFEFEF"

# fixní mapování rolí (NIKDY neměnit mezi figurami)
PAL_PRINCIPLES <- c(
  "Procedural" = MUNI_BLUE,
  "Equality"   = PED_ORANGE,
  "Needs"      = MU_GREEN,
  "Merit"      = MU_PURPLE
)
PAL_FAMILIES <- c(
  distributive  = PED_ORANGE,
  procedural    = MUNI_BLUE,
  interactional = MU_GREEN,
  rectificatory = MU_RED,
  macro         = "#767676"
)
PAL_VILLAGES <- c(
  "Equality (Blue)"          = MUNI_BLUE,
  "Need (Green)"             = MU_GREEN,
  "Merit (Orange)"           = PED_ORANGE,
  "Chance (White)"           = "#FFFFFF",
  "Equal opportunity (Red)"  = MU_RED,
  "Caste (Yellow)"           = MU_YELLOW
)
PAL_TIERS <- c(tier1 = MUNI_BLUE, tier2 = "#FFD9B8", tier3 = GREY_FILL)

# divergentní 1..7: oranžová (nespravedlivé) -> světlá -> MUNI modrá (spravedlivé)
BOOK_DIVERGING7 <- grDevices::colorRampPalette(
  c(PED_ORANGE, "#FFC08A", "#F4E8DC", GREY_FILL, "#C8CDF5", "#5A5AE8", MUNI_BLUE)
)(7)

# --- ggplot téma -----------------------------------------------------------
theme_book <- function(base_size = 12) {
  theme_minimal(base_size = base_size, base_family = "Helvetica") +
    theme(
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = GREY_FILL),
      panel.grid.major.x = element_blank(),
      axis.text  = element_text(color = "black"),
      axis.title = element_text(color = "black"),
      legend.title = element_text(size = base_size - 1),
      legend.text  = element_text(size = base_size - 2),
      plot.title = element_blank(),     # nadpisy nese popisek pod figurou
      plot.subtitle = element_blank(),
      plot.background  = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}

# uložení v jednotné kvalitě (300 dpi PNG + volitelně PDF).
# ragg/cairo kvůli unicode glyfům (→, ↔) — quartz/postscript je nemají.
save_book_fig <- function(path_png, plot, width = 9, height = 5, pdf_too = TRUE) {
  if (requireNamespace("ragg", quietly = TRUE)) {
    ggsave(path_png, plot, width = width, height = height, dpi = 300,
           bg = "white", device = ragg::agg_png)
  } else {
    ggsave(path_png, plot, width = width, height = height, dpi = 300,
           bg = "white", type = "cairo")
  }
  if (pdf_too) ggsave(sub("\\.png$", ".pdf", path_png), plot,
                      width = width, height = height, bg = "white",
                      device = grDevices::cairo_pdf)
  invisible(path_png)
}
