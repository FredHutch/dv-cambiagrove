#!/usr/bin/env nextflow

INPUT_CH = Channel.from([[
  file(params.output.folder+ '/format/cds3/data.rds'), 
  UUID.randomUUID().toString().substring(0,7)
]])

process MONOCLE3_PREPROCESS_PR {

  // publishDir "$params.output.folder/analysis/monocle3"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), val(ppid) from INPUT_CH
    each method from params.monocle3.preprocess.method
    each num_dim from params.monocle3.preprocess.num_dim
    each norm_method from params.monocle3.preprocess.norm_method
    each pseudo_count from params.monocle3.preprocess.pseudo_count

  output:
    set file("${ppid + '-' + pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid) into MONOCLE3_PREPROCESS_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 preprocess -f cds3 -F cds3 --method=${method} --num-dim=${num_dim} --norm-method=${norm_method} --pseudo-count=${pseudo_count} cds.rds ${ppid}-${pid}.rds
  echo "monocle3 preprocess method=${method} num-dim=${num_dim} norm-method=${norm_method} pseudo-count=${pseudo_count}" >> ${ppid +'-'+ pid}.txt
  """
}

process MONOCLE3_REDUCEDIM_PR {

  // publishDir "$params.output.folder/analysis/monocle3"
  container 'quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1'

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_PREPROCESS_CH
    each max_components from params.monocle3.reduce_dim.max_components
    each steps from params.monocle3.reduce_dim.steps

  output:
    set file("${ppid + '-'+ pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid), val(method) into MONOCLE3_REDUCEDIM_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)
    method = steps.split("-")[1]

  """
  preprocess=\$(echo ${steps} | cut -f1 -d-)
  reduction=\$(echo ${steps} | cut -f2 -d-)
  monocle3 reduceDim -f cds3 -F cds3 --preprocess-method=\$preprocess --reduction-method=\$reduction --max-components=${max_components} cds.rds ${ppid}-${pid}.rds
  cat ledger.txt > ${ppid +'-'+ pid}.txt
  echo "monocle3 reduceDim preprocess-method=\$preprocess reduction-method=\$reduction max-components=${max_components}" >> ${ppid +'-'+ pid}.txt
  """
}

process MONOCLE3_CLUSTER_PR {
  //publishDir "$params.output.folder/analysis/monocle3"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid), val(method) from MONOCLE3_REDUCEDIM_CH
    each resolution from params.monocle3.cluster.resolution
    each k from params.monocle3.cluster.k
    each louvain_iter from params.monocle3.cluster.louvain_iter
    each partition_qval from params.monocle3.cluster.partition_qval
    each weight from params.monocle3.cluster.weight
    
  output:
    set file("${ppid + '-'+ pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid) into MONOCLE3_CLUSTER_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)
  
  """
  echo 'library(Matrix)' >> tmp.R
  echo 'library(monocle3)' >> tmp.R
  echo 'cds <- readRDS("cds.rds")' >> tmp.R
  echo 'cds <- cluster_cells(cds, reduction_method="${method}", k=${k}, louvain_iter=${louvain_iter}, partition_qval=${partition_qval}, weight=${weight})' >> tmp.R
  echo 'saveRDS(cds, "${ppid + '-'+ pid}.rds")' >> tmp.R
  Rscript tmp.R
  cat ledger.txt > ${ppid +'-'+ pid}.txt
  echo "monocle3 cluster reduction_method="${method}" k=${k} louvain_iter=${louvain_iter} partition_qval=${partition_qval} weight=${weight}" >> ${ppid +'-'+ pid}.txt
  """
}
process MONOCLE3_PARTITION_PR {

  publishDir "$params.output.folder/analysis/monocle3"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_CLUSTER_CH
    each reduction_method from params.monocle3.partition.reduction_method
    each knn from params.monocle3.partition.knn
    each louvain_iter from params.monocle3.partition.louvain_iter
    each partition_qval from params.monocle3.partition.partition_qval

  output:
    set file("${ppid + '-'+ pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid) into MONOCLE3_PARTITION_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 partition -f cds3 -F cds3 --reduction-method=${reduction_method} --knn=${knn} --louvain-iter=${louvain_iter} cds.rds ${ppid+'-'+pid}.rds
  cat ledger.txt > ${ppid +'-'+ pid}.txt
  echo "monocle3 partition reduction-method=${reduction_method} knn=${knn} louvain-iter=${louvain_iter}" >> ${ppid +'-'+ pid}.txt
  """
}

process MONOCLE3_LEARNGRAPH_PR {

  errorStrategy 'ignore'  // Would be better to conditionally broacast if MONOCLE_PARTITION_CH Reduction Method = UMAP

  publishDir "$params.output.folder/analysis/monocle3"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_PARTITION_CH
    each euclidean_distance_ratio from params.monocle3.learn_graph.euclidean_distance_ratio
    each geodesic_distance_ratio from params.monocle3.learn_graph.geodesic_distance_ratio
    each minimal_branch_len from params.monocle3.learn_graph.minimal_branch_len

  output:
    set file("${ppid + '-'+ pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid) into MONOCLE3_LEARNGRAPH_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 learnGraph -f cds3 -F cds3 --euclidean-distance-ratio=${euclidean_distance_ratio} --geodesic-distance-ratio=${geodesic_distance_ratio} --minimal-branch-len=${minimal_branch_len} cds.rds ${ppid}-${pid}.rds
  cat ledger.txt > ${ppid +'-'+ pid}.txt
  echo "monocle3 learnGraph euclidean-distance-ratio=${euclidean_distance_ratio} geodesic-distance-ratio=${geodesic_distance_ratio} minimal-branch-len=${minimal_branch_len}" >> ${ppid +'-'+ pid}.txt
  """
}

/*
These methods will need to ve 
process MONOCLE3_ORDERCELLS_PR {

  publishDir "$params.output.folder/analysis/monocle3"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE3_LEARNGRAPH_CH
    each cell_phenotype from params.monocle3.order_cells.cell_phenotype
    each reduction_method from params.monocle3.order_cells.reduction_method
  
  output:
    set file("${ppid + '-'+ pid}.rds"), file("${ppid +'-'+ pid}.txt"), val(pid) into MONOCLE_ORDERCELLS_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  monocle3 orderCells -f cds3 -F cds3 --cell-phenotype=${cell_phenotype} --reduction-method=${reduction_method} --root-type=NULL cds.rds ${ppid}-${pid}.rds
  cat ledger.txt > ${ppid +'-'+ pid}.txt
  echo "monocle3 orderCells cell-phenotype=${cell_phenotype} reduction-method=${reduction_method}" >> ${ppid +'-'+ pid}.txt
  """
}

process monocle3_diffexp {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    set file("cds.rds"), file("ledger.txt"), val(ppid) from MONOCLE_ORDERCELLS_CH
    each neighbor_graph from params.monocle3.diff_exp.neighbor_graph
    each knn from params.monocle3.diff_exp.knn
    each alternative from params.monocle3.diff_exp.alternative

  output:
    set file("${ppid + '-'+ pid}.rds"), file("ledger.txt"), val(pid)

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

  """
  echo "$ppid-$pid monocle3 diffExp neighbor-graph=${neighbor_graph} reduction-method=${params.monocle3.order_cells.reduction_method} knn=${knn} method=${params.monocle3.diffexp.method} alternative=${alternative}" >> ledger.txt
  monocle3 diffExp -f cds3 -F cds3 --neighbor-graph=${neighbor_graph} --reduction-method=${params.monocle3.order_cells.reduction_method} --knn=${knn} --method=${ params.monocle3.diffexp.method} --alternative=${alternative} cds.rds ${ppid}-${pid}.rds
  """
}
*/
