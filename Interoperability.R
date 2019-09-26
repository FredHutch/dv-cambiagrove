# STEP 1: PACKAGE INSTALLATION
# STEP 2: LIBRARIES
# STEP 3: CREATE DATA
# STEP 4: CONVERT SEURAT TO 10X
# STEP 5: CONVERT SEURAT TO SINGLE CELL EXPERIEMENT
# STEP 6: CONVERT SEURAT TO .RDS
# STEP 7: CONVERT SEURAT TO LOOM
# STEP 8: CONVERT SEURAT TO ANNDATA(H5AD)
# STEP 9: CONVERT .RDS TO SEURAT
# STEP 10:` CONVERT LOOM TO SEURAT
# STEP 11: CONVERT SCE TO SEURAT
# STEP 12: CONVERT 10X TO SEURAT
# STEP 13: FUNCTION TO CALL ABOVE FUNCTIONS

# ----------------------------------------------------------------------------------------------------------

# STEP 1: PACKAGE INSTALLATION
install.packages("remotes")
remotes::install_github(repo ='mojaveazure/loomR', ref = 'develop')
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("scater")
remotes::install_version("Seurat")
install.packages("Seurat")
install.packages("Matrix")
install.packages("rio")
install.packages("devtools")
devtools::install_github(repo = "hhoeflin/hdf5r")
devtools::install_github(repo = "mojaveazure/loomR", ref = "develop", force=TRUE)
devtools::install_github(repo = "satijalab/seurat", ref = "loom")
BiocManager::install("DropletUtils")

# ----------------------------------------------------------------------------------------------------------

# STEP 2: PACKAGE LIBRARIES
library(scater)
library(loomR)
library(Seurat)
library(SingleCellExperiment)
library(Matrix)
library(SummarizedExperiment)
library(rio)
install_formats()
data("pbmc_small")
library(DropletUtils)

# ----------------------------------------------------------------------------------------------------------

#pbmc is an old Seurat class object
pbmc<-readRDS(file="C:\\Users\\mmehrotr\\Downloads\\pbmc3k_final.rds")

#Updated_pbmc holds the new Seurat object
updated_pbmc = UpdateSeuratObject(object = pbmc)

#Save a Seurat RDS file for testing
saveRDS(pbmc_small, file="SeuratToRDS.rds")

#Seurat object pbmc_small
pbmc_small

#Location for storing 10x file for testing
location="C:\\Users\\mmehrotr\\Downloads\\filtered_gene_bc_matrices\\hg19\\"
rds_location="C:\\Users\\mmehrotr\\Downloads\\manno_human.rds"
rds_locationForConversion="C:\\Users\\mmehrotr\\Desktop\\SeuratToRDS.rds"

# ----------------------------------------------------------------------------------------------------------

# STEP 4: CONVERT SEURAT TO 10X(MTX, CELL ANN, GENE ANN, BARCODES)
#browseVignettes("DropletUtils")
#pbmc is the RDS file format which takes old Seurat by default and updated_pbmc is of class new Seurat object
convert_seurat_10x(updated_pbmc)
convert_seurat_10x<-function(updated_pbmc){
  write10xCounts(path="C:\\Users\\mmehrotr\\Desktop\\SeuratTo10xData",x=updated_pbmc@assays$RNA@counts,barcodes=colnames(updated_pbmc@assays$RNA@counts), gene.id=rownames(updated_pbmc@assays$RNA@counts),
                 gene.symbol=rownames(updated_pbmc@assays$RNA@counts), gene.type="Gene Expression", overwrite=FALSE, 
                 type="auto")
  
}

# ----------------------------------------------------------------------------------------------------------

# STEP 5: CONVERT SEURAT TO SINGLE CELL EXPERIMENT
convert_seurat_sce<-function(updated_pbmc){
  pbmc.seuratToSCE <- as.SingleCellExperiment(updated_pbmc,assays = list(counts = counts))
  return(pbmc.seuratToSCE)
  }

# ----------------------------------------------------------------------------------------------------------

# STEP 6: CONVERT SEURAT TO RDS
convert_seurat_rds<-function(rds_locationForConversion){
  SeuToRDS<-readRDS(rds_locationForConversion)
  return(SeuToRDS)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 7: CONVERT SEURAT TO LOOM
convert_seurat_loom<-function(pbmc_small){
  pfile <- as.loom(pbmc_small)
  return(pfile)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 8: CONVERT SEURAT TO H5AD(ANNDATA)
convert_seurat_ann<-function(pmbc_small){
  pbmc3k <- ReadH5AD(file = "../data/pbmc3k.h5ad")
  return(pbmc3k)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 9: CONVERT .RDS TO SEURAT
convert_rds_seurat<-function(rds_location){
  manno <- readRDS(file = rds_location)
  manno.seurat <- as.Seurat(manno, counts = "counts", data = "logcounts")
  return(manno.seurat)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 10: CONVERT LOOM TO SEURAT
convert_loom_seurat<-function(pfile){
  LoomToSeu <- as.Seurat(pfile)
  return(LoomToSeu)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 11: CONVERT SCE TO SEURAT
convert_sce_seurat<-function(pbmc.sce){
  pbmc.sce.to.seurat<- as.Seurat(pbmc.sce)
  return(pbmc.sce.to.seurat)
}

# ----------------------------------------------------------------------------------------------------------

# STEP 12: CONVERT 10X INTO SEURAT
convert_10x_Seurat<-function(location){
  pbmc.data <- Read10X(data.dir = location)
  pbmc <- CreateSeuratObject(counts = pbmc.data, project = "Seurat", min.cells = 3, min.features = 200)	
  return(pbmc)
  }

# ----------------------------------------------------------------------------------------------------------

# STEP 13: FINAL FUNCTION TO CALL ABOVE FUNCTIONS
user.input<-readline(prompt="1. CONVERT SEURAT TO 10X\n2. CONVERT SEURAT TO SINGLE CELL EXPERIEMENT\n3. CONVERT SEURAT TO .RDS\n4. CONVERT SEURAT TO LOOM\n5. CONVERT .RDS TO SEURAT\n6. CONVERT LOOM TO SEURAT\n7. CONVERT SCE TO SEURAT\n8. CONVERT 10X TO SEURAT\n
Select an option:")
    





