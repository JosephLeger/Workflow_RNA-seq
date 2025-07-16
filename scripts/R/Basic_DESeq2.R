#!/usr/bin/env Rscript


#===============================================================================
## DESCRIPTION -----------------------------------------------------------------
#===============================================================================
# From : https://github.com/JosephLeger/Workflow_RNA-seq

# This script porceeds to post-processing analysis of Bulk RNA-seq data after 
# quantification with featureCount while using RAW COUNTS alignment workflow.

## CUSTOMIZATION ##
# All you have to do is replacing information in PROJECT INFO section, with your
# own folder pathways. 
# If the studied organisms is not Mus musculus or Homo sapiens, you will also
# need to proceed GeneSymbol annotation manually.
# In DESEQ2 DEG ANALYSIS section, you can modify filter conditions based on your
# own data distribution, or even apply customized filtering functions.



#===============================================================================
# SET UP -----------------------------------------------------------------------
#===============================================================================

rm(list=ls(all.names=TRUE))

################################################################################
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ PROJECT INFO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
################################################################################

PROJECT_NAME <- "Example_Project"
PATH         <- "C:/Path/to/project/directory"
INPUT_DIR    <- "C:/Path/to/data/directory"
SAMPLE_SHEET <- "C:/Path/to/Sample_Sheet.csv"
COMP_TO_MAKE <- "C:/Path/to/Comparisons_to_make.csv"

################################################################################
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
################################################################################

setwd(PATH)

# Load required packages and functions
library(Biobase)
library(dplyr)
library(stringr)
library(org.Mm.eg.db)
library(org.Hs.eg.db)
library(ggplot2)
library(pheatmap)
library(DESeq2)
library(EnhancedVolcano)

`%!in%` <- Negate(`%in%`)

# Create required directories
dir.create(file.path(PATH, 'Figures'))
dir.create(file.path(PATH, 'Saves'))
dir.create(file.path(PATH, 'Table'))
dir.create(file.path(paste0(PATH, '/Figures'), 'Heatmaps'))
dir.create(file.path(paste0(PATH, '/Saves'), 'DESeq2'))
dir.create(file.path(paste0(PATH, '/Saves'), 'GeneList'))
dir.create(file.path(paste0(PATH, '/Saves/GeneList'), 'padj'))
dir.create(file.path(paste0(PATH, '/Saves/GeneList'), 'pval'))

# Set up path for figures and saves
PATH_FIG  <- paste0(PATH, '/Figures')
PATH_SAVE <- paste0(PATH, '/Saves')



#===============================================================================
## INPUT -----------------------------------------------------------------------
#===============================================================================

# Read files
COUNT <- read.table(paste(INPUT_DIR, '/Count_Table.out', sep = ''), 
                    sep = '\t', header = TRUE, check.names = F)
METADATA      <- read.table(SAMPLE_SHEET, sep = ',', header = T)
COMPARISONS   <- read.csv(COMP_TO_MAKE)



#===============================================================================
## DATA FORMAT -----------------------------------------------------------------
#===============================================================================

# Create table and reorder samples based on sheet row order
Table <- data.frame(matrix(0, nrow(COUNT), ncol(COUNT)-6))
for(i in 1:length(METADATA$File)){
  Table[,i] <- COUNT[,grep(METADATA$File[i], colnames(COUNT))]
}
colnames(Table) <- METADATA$Sample
rownames(Table) <- COUNT$Geneid

# Changing Ensembl id to GeneSymbol using org.Mm.eg.db / org.Hs.eg.db
ID     <- rownames(Table)
mapped <- mapIds(org.Mm.eg.db, 
                 keys = ID,
                 keytype = 'ENSEMBL', 
                 column = 'SYMBOL')
mapped <- data.frame(ID = names(mapped), Symbol = mapped)

# Define function to fill in faster than iteration
fill_if_NA <- function(line){
  if(is.na(line[2])){
    return(line[1])
  }else{
    return(line[2])
  }
}
Symbol <-  apply(mapped, 1, fill_if_NA)
Table  <- cbind(Symbol = Symbol, Table)
Table  <- Table[order(rownames(Table)),]

# Save Table
write.table(Table, paste0(PATH, '/Table/Table_Raw.txt'), 
            sep = '\t', row.names = TRUE, quote = FALSE)



#===============================================================================
## SEX ANALYSIS ----------------------------------------------------------------
#===============================================================================
# Optional part to check concordance between data and provided sample sheet
# We check if sex-specific genes are expressed consistently across the dataset

# Read table
Table <- read.table(paste0(PATH, '/Table/Table_Raw.txt'), 
                    sep = '\t', check.names = FALSE)
# Set sex specific gene lists and subset Table
Female_genes <- c('Xist', 'Eif2s3x', 'Kdm6a')
Male_genes   <- c('Uty', 'Eif2s3y', 'Kdm5d')

Table_Sex    <- Table[match(c(Female_genes, Male_genes), Table$Symbol),]

# Draw heatmap
heatdata     <- Table_Sex[,2:ncol(Table_Sex)]
sex_groups   <- pheatmap(log2(heatdata+1), 
                         show_rownames = TRUE, 
                         labels_row = c(Female_genes, Male_genes), 
                         cluster_rows = F, 
                         cluster_cols = F, 
                         scale = 'row')
ggsave(paste0(PATH_FIG, '/Sex_Analysis.png'), sex_groups, width = 9, height = 9)



#===============================================================================
## HEATMAP & SAMPLE REPARTITION ------------------------------------------------
#===============================================================================

# Load Table
Table <- read.table(paste0(PATH, '/Table/Table_Raw.txt'),
                    sep = '\t', check.names = FALSE)

## HEATMAPS BY SAMPLE GROUPS ---------------------------------------------------

# Generate and store heatmaps in a list
plot_list        <- list()
for(g in names(table(METADATA$Group))){
  heatdata       <- Table[,as.character(METADATA$Sample[METADATA$Group %in% g])]
  heatdata$count <- apply(heatdata, 1, sum)
  # Eliminate low expressed genes (use custom threshold)
  heatdata       <- subset(heatdata, count > ncol(heatdata))
  heatdata$count <- NULL
  plot_list[[g]] <- pheatmap(log2(heatdata+1), 
                             show_rownames = FALSE, 
                             treeheight_row = 0, 
                             cluster_cols = FALSE)
}
# Save heatmaps as png files
for(g in names(table(METADATA$Group))){
  png(paste0(PATH_FIG, '/Heatmaps/group_', g, '.png'), 
      width = 9, height = 9, units = "in", res = 100)
  print(plot_list[[g]])
  dev.off()
}


## HEATMAP WITH ALL SAMPLES ----------------------------------------------------

# Eliminate low row values
pheatdata       <- Table[,2:ncol(Table)]
pheatdata$count <- apply(pheatdata, 1, sum)
pheatdata       <- subset(pheatdata, count > ncol(pheatdata))
pheatdata$count <- NULL

# Save heatmap with all groups
all_groups <- pheatmap(log2(pheatdata+1), 
                       show_rownames = FALSE, 
                       treeheight_row = 25, 
                       treeheight_col = 25, 
                       cluster_cols = TRUE)

png(paste0(PATH_FIG, '/Heatmaps/all_groups.png'), 
    width = 9, height = 9, units = 'in', res = 100)
print(all_groups)
dev.off()


## DENDROGRAM ------------------------------------------------------------------

dendodata          <- t(Table[,2:ncol(Table)])
dist               <- dist(dendodata[ ,c(1:ncol(dendodata))] , 
                           diag=TRUE, method = 'euclidian')
hc                 <- hclust(dist)
plot(hc, main = '', xlab = 'Samples', sub = '')

png(paste0(PATH_FIG, '/dendro.png'), 
    width = 9, height = 9, units = 'in', res = 100)
plot(hc, main = "", xlab = 'Samples', sub = '')
dev.off()



#===============================================================================
## NORMALIZATION ---------------------------------------------------------------
#===============================================================================

# Normalization
dds        <- DESeqDataSetFromMatrix(countData = Table[,2:ncol(Table)], 
                                     colData = METADATA, design = ~ Group)
mcols(dds) <- cbind(mcols(dds), Symbol = Table[,1])
dds        <- estimateSizeFactors(dds)
data       <- counts(dds, normalized = TRUE)
dds@assays@data@listData[['normalized']] <- data

dds        <- DESeq(dds)

# Saving DDS object
saveRDS(dds, paste0(PATH_SAVE, '/DESeq2_DDS.rds'))

# Save Normalized Table
Table_norm <- cbind(Symbol = Table[,1], 
                    dds@assays@data@listData[['normalized']])
write.table(Table_norm, paste0(PATH, '/Table/Table_Norm.txt'), 
            sep = '\t', row.names = TRUE, quote = FALSE)



#===============================================================================
## HEATMAP & SAMPLE REPARTITION AFTER NORMALIZATION ----------------------------
#===============================================================================

## HEATMAPS BY SAMPLE GROUPS ---------------------------------------------------

# Generate and store heatmaps in a list
plot_list  <- list()
for(g in names(table(METADATA$Group))){
  heatdata <- as.data.frame(dds@assays@data[['normalized']][
    ,as.character(METADATA$Sample[METADATA$Group %in% g])])
  heatdata$count <- apply(heatdata, 1, sum)
  # Eliminate low expressed genes (use custom threshold)
  heatdata       <- subset(heatdata, count > ncol(heatdata))
  heatdata$count <- NULL
  plot_list[[g]] <- pheatmap(log2(heatdata+1), 
                             show_rownames = FALSE, 
                             treeheight_row = 50, 
                             treeheight_col = 50,
                             cluster_cols = FALSE)
}
# Save heatmaps as png files
for(g in names(table(METADATA$Group))){
  png(paste0(PATH_FIG, '/Heatmaps/group_', g, '_norm.png'),
      width = 9, height = 9, units = 'in', res = 100)
  print(plot_list[[g]])
  dev.off()
}

## HEATMAP WITH ALL SAMPLES ----------------------------------------------------

pheatdata       <- as.data.frame(dds@assays@data[['normalized']])
pheatdata$count <- apply(pheatdata, 1, sum)
pheatdata       <- subset(pheatdata, count > ncol(pheatdata))
pheatdata$count <- NULL

# Save heatmap with all groups
all_groups_norm <- pheatmap(log2(pheatdata + 1), 
                            show_rownames = FALSE, 
                            treeheight_row = 25, 
                            treeheight_col = 25, 
                            cluster_cols = TRUE)

png(paste0(PATH_FIG, '/Heatmaps/all_groups_norm.png'), 
    width = 9, height = 9, units = 'in', res = 100)
print(all_groups_norm)
dev.off()

## DENDROGRAM ------------------------------------------------------------------

dendodata          <- t(dds@assays@data[['normalized']])
dist               <- dist(dendodata[ ,c(1:ncol(dendodata))] , 
                           diag=TRUE, method = 'euclidian')
hc                 <- hclust(dist)
plot(hc, main = '', xlab = 'Samples', sub = '')

# Save dendrogram of samples
png(paste0(PATH_FIG, '/dendro_norm.png'), 
    width = 9, height = 9, units = 'in', res = 100)
plot(hc, main = "", xlab = 'Samples', sub = '')
dev.off()



#===============================================================================
## DESEQ2 DEG ANALYSIS ---------------------------------------------------------
#===============================================================================

# Load Table and DDS object
Table <- read.table(paste0(PATH, '/Table/Table_Raw.txt'), 
                    sep = '\t', check.names = FALSE)
dds   <- readRDS(paste0(PATH_SAVE, '/DESeq2_DDS.rds'))


## DEG ANALYSIS ----------------------------------------------------------------

res   <- list()

for( i in 1:nrow(COMPARISONS)){
  
  # Set current comparison members
  control <- COMPARISONS$Control[i] 
  tested  <- COMPARISONS$Tested[i]
  title   <- paste(tested, 'vs', control, sep = '_')
  
  # Full Result list, adding Symbols and reorder list
  res[[title]] <- results(dds, contrast = c('Group', tested, control))
  new.order                <- c('Symbol', names(res[[i]]@listData))
  res[[title]]@listData$Symbol <- mcols(dds)$Symbol 
  res[[title]]@listData        <- res[[i]]@listData[new.order]
  
  # Filtered Result list for volcano plots and store corresponding Symbols
  #filtered_res[[i]] <- results(subset(dds, rownames(dds) %!in% eliminate), 
  #                             contrast = c('Group', tested, control))
  #Symbol <- mcols((subset(dds, rownames(dds) %!in% eliminate)))$Symbol
  
  
  # PLOT MA -------------------------------------------------------------------
  
  ggplot(as.data.frame(res[[title]]@listData), 
         aes(x = log10(as.numeric(baseMean)), y = as.numeric(log2FoldChange))) +
    geom_point() + 
    ggtitle(title) +
    labs(x = 'Log10(baseMean)', y = 'Log2 FoldChange')
  # Save plotMA
  ggsave(paste0(PATH_FIG, '/', title, '_MAplot.png'), 
         width = 2500, height = 2000, units = "px")
  
  
  ## VOLCANO PLOT WITH PVALUE --------------------------------------------------
  
  # Attribute a color for each gene
  keyvals <- ifelse(
    res[[title]]@listData[['log2FoldChange']] < -1 & 
      res[[title]]@listData[['pvalue']] < 0.05, 'royalblue',
    ifelse(
      res[[title]]@listData[['log2FoldChange']] > 1 & 
        res[[title]]@listData[['pvalue']] < 0.05, 'red',
      'grey'))
  # Attribute corresponding legend
  keyvals[is.na(keyvals)]                <- 'grey'
  names(keyvals)[keyvals == 'red']       <- 'Up'
  names(keyvals)[keyvals == 'grey']      <- 'NS'
  names(keyvals)[keyvals == 'royalblue'] <- 'Down'
  # Draw Volcano plot
  EnhancedVolcano(res[[title]]@listData, lab = Symbol, 
                  x = 'log2FoldChange', y = 'pvalue', 
                  title = title, subtitle = '', legendPosition = 'right',
                  selectLab = Symbol[which(names(keyvals) %in% c('Up','Down'))],
                  pCutoff = 0.05, FCcutoff = 1, pointSize = 1.2, labSize = 3,
                  colCustom = keyvals, colAlpha = 1,
                  ylab = bquote(~-Log[10] ~ italic(Pvalue)))
  
  # Save volcano plot
  ggsave(paste0(PATH_FIG, '/', title, '_Volcano_pval.png'), 
         width = 3000, height = 2500, units = 'px')
  
  
  ## VOLCANO PLOT WITH PADJUSTED VALUE -----------------------------------------
  
  # Attribute a color for each gene
  keyvals <- ifelse(
    res[[title]]@listData[['log2FoldChange']] < -1 & 
      res[[title]]@listData[['padj']] < 0.05, 'royalblue',
    ifelse(
      res[[title]]@listData[['log2FoldChange']] > 1 & 
        res[[title]]@listData[['padj']] < 0.05, 'red',
      'grey'))
  # Attribute corresponding legend
  keyvals[is.na(keyvals)]                <- 'grey'
  names(keyvals)[keyvals == 'red']       <- 'Up'
  names(keyvals)[keyvals == 'grey']      <- 'NS'
  names(keyvals)[keyvals == 'royalblue'] <- 'Down'
  # Draw Volcano plot
  EnhancedVolcano(res[[title]]@listData, lab = Symbol, 
                  x = 'log2FoldChange', y = 'padj', 
                  title = title, subtitle = '',
                  legendPosition = 'right',
                  selectLab = Symbol[which(names(keyvals) %in% c('Up','Down'))],
                  pCutoff = 0.05, FCcutoff = 1, 
                  pointSize = 1.2, labSize = 3,
                  colCustom = keyvals, colAlpha = 1,
                  ylab = bquote(~-Log[10] ~ italic(Padj)))
  # Save volcano plot
  ggsave(paste0(PATH_FIG, '/', title, '_Volcano_padj.png'),
         width = 3000, height = 2500, units = 'px')
  
  
  ## SAVE STATISTICAL RESULTS --------------------------------------------------
  
  # Result Table of genes of interest
  write.table(res[[title]]@listData, 
              paste0(PATH_SAVE, '/DESeq2/', title, '.txt'), 
              sep = '\t', row.names = res[[title]]@rownames, quote = FALSE)
}

# Save file listing all results
saveRDS(res, paste0(PATH_SAVE, '/DESeq2_Res.RDS'))


#===============================================================================
## FINAL RESULTS FORMAT --------------------------------------------------------
#===============================================================================

res <- readRDS(paste0(PATH_SAVE, '/DESeq2_Res.RDS'))


## FINAL GENE LISTS ------------------------------------------------------------

for(i in 1:length(res)){
  # Reading saved DESeq2 stat tables
  y    <- as.data.frame(res[[i]]@listData)
  name <- names(res)[i]
  
  ## P-VALUE GENE LISTS
  up_pval   <- unique(y$Symbol[y$log2FoldChange > 1 & y$pvalue < 0.05])
  down_pval <- unique(y$Symbol[y$log2FoldChange < -1 & y$pvalue < 0.05])
  final_list_pval <- data.frame(gene = c(up_pval, down_pval), 
                                expression = c(rep('UP', length(up_pval)), 
                                               rep('DOWN', length(down_pval))))
  
  write.table(up_pval, paste0(PATH_SAVE, '/GeneList/pval/',
                              name, '_UP_pval.txt'), 
              sep = '\t', quote = FALSE, row.names = FALSE, col.names = F)
  write.table(down_pval, paste0(PATH, '/Saves/GeneList/pval/', 
                                name, '_DOWN_pval.txt'), 
              sep = '\t', quote = FALSE, row.names = FALSE, col.names = F)
  
  
  ## P-ADJ GENE LISTS 
  up_padj   <- unique(y$Symbol[y$log2FoldChange > 1 & 
                                 y$padj < 0.05 & !is.na(y$padj)])
  down_padj <- unique(y$Symbol[y$log2FoldChange < -1 & 
                                 y$padj < 0.05 & !is.na(y$padj)])
  final_list_padj <- data.frame(gene = c(up_padj, down_padj), 
                                expression = c(rep('UP', length(up_padj)), 
                                               rep('DOWN', length(down_padj))))  
  
  write.table(up_padj, 
              paste0(PATH_SAVE, '/GeneList/padj/', name, '_UP_adj.txt'), 
              sep = '\t', quote = FALSE, row.names = FALSE, col.names = F)
  write.table(down_padj, 
              paste0(PATH_SAVE, '/GeneList/padj/', name, '_DOWN_padj.txt'), 
              sep = '\t', quote = FALSE, row.names = FALSE, col.names = F)
}



## RESULT TABLE FORMAT ---------------------------------------------------------

Table_Results <- as.data.frame(read.table(paste0(PATH, '/Table/Table_Norm.txt'), 
                                         check.names = FALSE))
# Add groups mean
for(g in names(table(METADATA$Group))){
  x <- Table_Results[,as.character(METADATA$Sample[METADATA$Group %in% g])]
  Table_Results[,paste0('mean_', g)] <- apply(x, 1, mean)
}

# Add DESeq2 stats
for(i in 1:length(res)){
  # Reading saved DESeq2 stat tables
  x    <- as.data.frame(res[[i]]@listData)
  name <- names(res)[i]
  
  Table_Results[,paste(name, 'log2FC', sep = '_')] <- x$log2FoldChange 
  Table_Results[,paste(name, 'pval', sep = '_')]   <- x$pvalue
  Table_Results[,paste(name, 'padj', sep = '_')]   <- x$padj
}

# Save complete table regrouping all important informations
write.table(Table_Results, paste0(PATH, '/Table/Table_Results.txt'), 
            sep = '\t', quote = FALSE, row.names = TRUE, col.names = TRUE)








