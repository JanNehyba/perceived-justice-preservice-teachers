#!/usr/bin/env Rscript
# E5.1 human validation: reliability among 2 human coders + 3 LLM coders on the 5-concept pilot.
suppressPackageStartupMessages(library(irr))
PROC <- Filter(dir.exists, c("../data/processed","data/processed"))[1]
rd <- function(p) read.csv(file.path(PROC,p), stringsAsFactors=FALSE)

h <- rd("validation_pilot_FILLED.csv"); h$key <- paste(h$taxon_id, h$char_id, sep="_")
llm <- list(opus=rd("typology_matrix_opus.csv"), openai=rd("typology_matrix_openai.csv"), glm=rd("typology_matrix_glm.csv"))
llm <- lapply(llm, function(m){ m$key<-paste(m$taxon_id,m$char_id,sep="_"); m$code[match(h$key,m$key)] })

raters <- rbind(coder_A=h$code_coder_A, coder_B=h$code_coder_B, opus=llm$opus, openai=llm$openai, glm=llm$glm)
lev <- unique(as.vector(raters))
A <- function(rows) irr::kripp.alpha(matrix(match(raters[rows,,drop=FALSE],lev), nrow=length(rows)), method="nominal")$value
agree <- function(a,b) mean(raters[a,]==raters[b,])

cons <- sapply(seq_len(ncol(raters)), function(j){ v<-raters[c("opus","openai","glm"),j]; tb<-sort(table(v),decreasing=TRUE); if(tb[1]>=2) names(tb)[1] else v["opus"] })

a_hh   <- A(c("coder_A","coder_B"))                     # human-human
a_all5 <- A(c("coder_A","coder_B","opus","openai","glm"))
a_llm  <- A(c("opus","openai","glm"))                 # 3 LLM on pilot
lev2 <- lev
kripp2 <- function(x,y) irr::kripp.alpha(matrix(match(rbind(x,y),lev2),nrow=2),method="nominal")$value
a_A_cons <- kripp2(raters["coder_A",], cons); a_B_cons <- kripp2(raters["coder_B",], cons)

cat(sprintf("Human-human alpha (coder_A vs coder_B):        %.3f  (%.0f%% agree)\n", a_hh, 100*agree("coder_A","coder_B")))
cat(sprintf("3 LLM coders alpha (pilot):                  %.3f\n", a_llm))
cat(sprintf("All 5 raters alpha (2 human + 3 LLM):        %.3f\n", a_all5))
cat(sprintf("Human vs LLM-consensus alpha: coder_A=%.3f  coder_B=%.3f\n", a_A_cons, a_B_cons))
cat(sprintf("LLM consensus vs each human (%% agree): coder_A=%.0f%%  coder_B=%.0f%%\n",
    100*mean(raters["coder_A",]==cons), 100*mean(raters["coder_B",]==cons)))

pass <- min(a_A_cons, a_B_cons) >= 0.6
man <- file.path(PROC,"..","..","vystupy","tabulky","E5_typologie_cisla.csv")
m <- read.csv(man, stringsAsFactors=FALSE)
m <- m[!grepl("^val_|^human_validation$", m$metric),]
add <- data.frame(metric=c("human_validation","val_alpha_human_human","val_alpha_all5_raters",
        "val_alpha_3llm_pilot","val_jan_vs_consensus_alpha","val_colleague_vs_consensus_alpha","val_killswitch_pass",
        "val_alpha_note"),
        value=c("DONE (2 human coders + 3 LLM)", round(a_hh,3), round(a_all5,3), round(a_llm,3),
                round(a_A_cons,3), round(a_B_cons,3), pass,
                "legacy pooled-feature diagnostics; not interpreted in book; pilot described by exact-match pattern"))
write.csv(rbind(m,add), man, row.names=FALSE)
cat(sprintf("\nKILL-SWITCH (both humans vs LLM-consensus alpha >= .6): %s\n", if(pass)"PASS" else "FAIL"))
