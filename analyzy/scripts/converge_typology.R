#!/usr/bin/env Rscript
# E5.1 wording-based lens + convergence diagnostics.
# The two representations share the concept set and working definitions but use different
# similarity inputs: embedding distances versus theory-defined feature scores. Partial
# agreement is a sensitivity check, not independent validation.
suppressPackageStartupMessages({library(cluster); library(phangorn); library(ape); library(mclust); library(igraph)})
PROC <- Filter(dir.exists, c("../data/processed","data/processed"))[1]
TAB  <- file.path(PROC,"..","..","vystupy","tabulky")
FIG  <- file.path(PROC,"..","..","vystupy","obrazky")
rd  <- function(p) read.csv(file.path(PROC,p), stringsAsFactors=FALSE, check.names=FALSE)
rdt <- function(p) read.csv(file.path(TAB,p),  stringsAsFactors=FALSE, check.names=FALSE)

taxa <- rd("typology_taxa.csv")
# --- character-coded distance (consensus; written to vystupy/tabulky by 50_typology.qmd) ---
cons <- rdt("E5_consensus_matrix.csv"); rownames(cons) <- cons$taxon
CH <- setdiff(names(cons), "taxon")
Wc <- cons[, CH]; Wc[] <- lapply(Wc, factor)
Dc <- cluster::daisy(Wc, metric="gower")
ord <- rownames(cons)                                   # canonical taxon order

# --- embedding distance, aligned to the same taxon order ---
E <- rd("typology_embed_dist.csv"); rownames(E) <- E[[1]]; E <- as.matrix(E[,-1])
E <- E[ord, ord]                                        # align rows/cols to consensus order
De <- as.dist(E)

# --- convergence of the two complementary distance structures ---
mant_p <- cor(as.vector(Dc), as.vector(De), method="pearson")
mant_s <- cor(as.vector(Dc), as.vector(De), method="spearman")
hc_c <- hclust(Dc,"ward.D2"); hc_e <- hclust(De,"ward.D2")
coph  <- cor(cophenetic(hc_c), cophenetic(hc_e))        # cophenetic correlation between trees
rf    <- phangorn::RF.dist(ape::as.phylo(hc_c), ape::as.phylo(hc_e))
rf_norm <- as.numeric(rf) / (2*(length(ord)-3))         # normalised 0..1
fam <- factor(taxa$family[match(ord, taxa$taxon)]); k <- nlevels(fam)
cl_c <- cutree(hc_c,k); cl_e <- cutree(hc_e,k)
ari_ce <- mclust::adjustedRandIndex(cl_c, cl_e)
ari_ef <- mclust::adjustedRandIndex(cl_e, as.integer(fam))

cat(sprintf("Distance correlation (char vs embed):  Pearson %.3f | Spearman %.3f\n", mant_p, mant_s))
cat(sprintf("Cophenetic correlation between trees:  %.3f\n", coph))
cat(sprintf("Robinson-Foulds (normalised):          %.3f  (raw %d / %d)\n", rf_norm, as.integer(rf), 2*(length(ord)-3)))
cat(sprintf("ARI char-cluster vs embed-cluster:     %.3f\n", ari_ce))
cat(sprintf("ARI embed-cluster vs a priori families:%.3f\n", ari_ef))

# Figures have one authoritative writer: fig_E5_trees.R. Keeping this script numerical-only
# prevents a notebook rerun from replacing the book-styled Ward dendrogram with a NeighborNet.

# --- append results to manifest (do not clobber other keys) ---
man <- file.path(PROC,"..","..","vystupy","tabulky","E5_typologie_cisla.csv")
m <- read.csv(man, stringsAsFactors=FALSE); m <- m[!m$metric %in% c("second_lens_embedding",
  "conv_dist_cor_pearson","conv_dist_cor_spearman","conv_cophenetic_r","conv_RF_norm",
  "conv_ARI_char_vs_embed","conv_ARI_embed_vs_families"),]
add <- data.frame(metric=c("second_lens_embedding","conv_dist_cor_pearson","conv_dist_cor_spearman",
  "conv_cophenetic_r","conv_RF_norm","conv_ARI_char_vs_embed","conv_ARI_embed_vs_families"),
  value=c("DONE (OpenAI text-embedding-3-large; character-free)", round(mant_p,3), round(mant_s,3),
  round(coph,3), round(rf_norm,3), round(ari_ce,3), round(ari_ef,3)))
write.csv(rbind(m,add), man, row.names=FALSE)
cat("\nappended convergence metrics to E5_typologie_cisla.csv\n")
