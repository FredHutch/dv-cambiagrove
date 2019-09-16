#!/usr/bin/env nextflow

INPUT_CH = Channel.from([[
  file(params.input.exp), 
  file(params.input.col), 
  file(params.input.row), 
  UUID.randomUUID().toString().substring(0,7)
]])

INPUT_CH.into {
  TENX_INPUT_CH
  CDS_INPUT_CH
}

process TENX_LOAD_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"

  input:
    set file('exp.rds'), file('col.rds'), file('row.rds'), val(ppid) from TENX_INPUT_CH

  output:
    set file('matrix.mtx'), file('barcodes.tsv'), file('cells.tsv'), file('genes.tsv'), val(pid) into TENX_LOAD_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  #!/usr/bin/env Rscript 
  library(Matrix)
  library(Seurat)
  expression_matrix <- readRDS("exp.rds")
  cell_metadata <- readRDS("col.rds")
  gene_annotation <- readRDS("row.rds")
  writeMM(expression_matrix, 'matrix.mtx')
  write.table(row.names(cell_metadata), "barcodes.tsv", quote=FALSE, sep='\t', row.names=F, col.names=F)
  write.table(cell_metadata, "cells.tsv", quote=FALSE, sep='\t', row.names=T, col.names=T)
  write.table(gene_annotation, "genes.tsv", quote=FALSE, sep='\t', row.names=T, col.names=F)
  """
}

TENX_LOAD_CH.into {
  SEURAT_INPUT_CH
  ANNDATA_LOAD_CH
}

process ANNDATA_LOAD_PR {

}

process SEURAT_LOAD_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"

  input:
    set file('matrix.mtx'), file('barcodes.tsv'), file('cells.tsv'), file('genes.tsv'), val(ppid) from SEURAT_INPUT_CH

  output:
    set file("${ppid + '-' + pid}.rds"), file('ledger.txt'), val(pid) into SEURAT_LOAD_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  Rscript /usr/local/bin/seurat-read-10x.R -d \$PWD -o seurat-tmp.rds
  Rscript /usr/local/bin/seurat-create-seurat-object.R -i seurat-tmp.rds -o ${ppid + '-' + pid}.rds
  echo "$ppid-$pid seurat create" >> ledger.txt
  """
}

process SEURAT_NORMALIZE_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"
  
  input:
    set file("seurat.rds"), file("ledger.txt"), val(ppid) from SEURAT_LOAD_CH
    each assay_type from params.seurat.normalize.assay_type
    each normalization_method from params.seurat.normalize.normalization_method
    each scale_factor from params.seurat.normalize.scale_factor

  output:
    set file("${ppid + '-' + pid}.rds"), file('ledger.txt'), val(pid) into SEURAT_NORMALIZE_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  Rscript /usr/local/bin/seurat-normalise-data.R -i seurat.rds -a ${assay_type} -n ${normalization_method} -s ${scale_factor} -o ${ppid + '-' + pid}.rds
  echo "$ppid-$pid seurat normalize" assay-type=${assay_type} normalization_method=${normalization_method} scale_factor=${scale_factor} >> ledger.txt
  """
}

process SEURAT_VARIABLEGENES_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"
  
  input:
    set file("seurat.rds"), file("ledger.txt"), val(ppid) from SEURAT_NORMALIZE_CH
    each mean_function from params.seurat.variable_genes.mean_function
    each dispersion_function from params.seurat.variable_genes.dispersion_function
    each fvg_x_low_cutoff from params.seurat.variable_genes.fvg_x_low_cutoff
    each fvg_y_low_cutoff from params.seurat.variable_genes.fvg_y_low_cutoff
    each fvg_x_high_cutoff from params.seurat.variable_genes.fvg_x_high_cutoff
    each fvg_y_high_cutoff from params.seurat.variable_genes.fvg_y_high_cutoff

  output:
    set file("${ppid + '-' + pid}.rds"), file('ledger.txt'), val(pid) into SEURAT_VARIABLEGENES_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  Rscript /usr/local/bin/seurat-find-variable-genes.R -i seurat.rds -m ${mean_function} -d ${dispersion_function} -l ${fvg_x_low_cutoff} -j ${fvg_x_high_cutoff} -y ${fvg_y_low_cutoff} -z ${fvg_y_high_cutoff} -o ${ppid + '-' + pid}.rds -t ${ppid + '-' + pid}.txt
  echo "$ppid-$pid seurat variableGenes" mean-function=${mean_function} dispersion-function=${dispersion_function} fvg-x-low-cutoff=${fvg_x_low_cutoff} fvg-x-high-cutoff=${fvg_x_high_cutoff} fvg-y-low-cutoff=${fvg_y_low_cutoff} fvg-y-high-cutoff=${fvg_y_high_cutoff} >> ledger.txt
  """
}

process SEURAT_

process CDS_LOAD_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file('exp.rds'), file('col.rds'), file('row.rds'), val(ppid) from CDS_INPUT_CH

  output:
    set file("${ppid + '-' + pid}.rds"), file('ledger.txt'), val(pid) into CDS_LOAD_CH

 script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  monocle3 create -F cds3 --cell-metadata=col.rds --gene-annotation=row.rds --expression-matrix=exp.rds ${ppid + '-' + pid}.rds
  echo "$ppid-$pid monocle3 create" >> ledger.txt
  """
}

process MONOCLE3_PREPROCESS_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from CDS_LOAD_CH
    each method from params.monocle.preprocess.method
    each num_dim from params.monocle.preprocess.num_dim
    each norm_method from params.monocle.preprocess.norm_method

  output:
    set file("${ppid + '-' + pid}.rds"), file('ledger.txt'), val(pid) into MONOCLE3_PREPROCESS_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 preprocess -f cds3 -F cds3 --method=${method} --num-dim=${num_dim} --norm-method=${norm_method} --pseudo-count=${params.monocle.preprocess.pseudo_count} cds.rds ${ppid}-${pid}.rds
  echo "$ppid-$pid monocle3 preprocess method=${method} num-dim=${num_dim} norm-method=${norm_method} pseudo-count=${params.monocle.preprocess.pseudo_count}" >> ledger.txt
  """
}

process MONOCLE3_REDUCEDIM_PR {

  publishDir "$params.output.folder"
  container 'quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1'

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_PREPROCESS_CH
    each max_components from params.monocle.reduce_dim.max_components
    each steps from params.monocle.reduce_dim.steps

  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid) into MONOCLE3_REDUCEDIM_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  preprocess=\$(echo ${steps} | cut -f1 -d-)
  reduction=\$(echo ${steps} | cut -f2 -d-)
  echo "$ppid-$pid monocle3 reduceDim preprocess-method=\$preprocess reduction-method=\$reduction max-components=${max_components}" >> ledger.txt
  monocle3 reduceDim -f cds3 -F cds3 --preprocess-method=\$preprocess --reduction-method=\$reduction --max-components=${max_components} cds.rds ${ppid}-${pid}.rds
  """
}

process MONOCLE3_PARTITION_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_REDUCEDIM_CH
    each reduction_method from params.monocle.partition.reduction_method
    each knn from params.monocle.partition.knn
    each louvain_iter from params.monocle.partition.louvain_iter
  
  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid) into MONOCLE3_PARTITION_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 partition -f cds3 -F cds3 --reduction-method=${reduction_method} --knn=${knn} --louvain-iter=${louvain_iter} cds.rds ${ppid+'-'+pid}.rds
  echo "$ppid-$pid monocle3 partition reduction-method=${reduction_method} knn=${knn} louvain-iter=${louvain_iter}" >> ledger.txt
  """
}

process MONOCLE3_LEARNGRAPH_PR {

  errorStrategy 'ignore'  // Would be better to conditionally broacast if MONOCLE_PARTITION_CH Reduction Method = UMAP

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_PARTITION_CH
    each euclidean_distance_ratio from params.monocle.learn_graph.euclidean_distance_ratio
    each geodesic_distance_ratio from params.monocle.learn_graph.geodesic_distance_ratio
    each minimal_branch_len from params.monocle.learn_graph.minimal_branch_len

  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid) into MONOCLE3_LEARNGRAPH_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 learnGraph -f cds3 -F cds3 --euclidean-distance-ratio=${euclidean_distance_ratio} --geodesic-distance-ratio=${geodesic_distance_ratio} --minimal-branch-len=${minimal_branch_len} cds.rds ${ppid}-${pid}.rds
  echo "$ppid-$pid monocle3 learnGraph euclidean-distance-ratio=${euclidean_distance_ratio} geodesic-distance-ratio=${geodesic_distance_ratio} minimal-branch-len=${minimal_branch_len}" >> ledger.txt
  """
}

/*
process monocle3_ordercells {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE_LEARNGRAPH_CH
    each cell_phenotype from params.monocle.order_cells.cell_phenotype
  
  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid) into MONOCLE_ORDERCELLS_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  echo "$ppid-$pid monocle3 orderCells cell-phenotype=${cell_phenotype} reduction-method=${params.monocle.order_cells.reduction_method}" >> ledger.txt
  monocle3 orderCells -f cds3 -F cds3 --cell-phenotype=${cell_phenotype} --reduction-method=${params.monocle.order_cells.reduction_method} cds.rds ${ppid}-${pid}.rds
  """
}

process monocle3_diffexp {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE_ORDERCELLS_CH
    each neighbor_graph from params.monocle.diff_exp.neighbor_graph
    each knn from params.monocle.diff_exp.knn
    each alternative from params.monocle.diff_exp.alternative

  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid)

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  echo "$ppid-$pid monocle3 diffExp neighbor-graph=${neighbor_graph} reduction-method=${params.monocle.order_cells.reduction_method} knn=${knn} method=${params.monocle.diffexp.method} alternative=${alternative}" >> ledger.txt
  monocle3 diffExp -f cds3 -F cds3 --neighbor-graph=${neighbor_graph} --reduction-method=${params.monocle.order_cells.reduction_method} --knn=${knn} --method=${ params.monocle.diffexp.method} --alternative=${alternative} cds.rds ${ppid}-${pid}.rds
  """
}
*/
