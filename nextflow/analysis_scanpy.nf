#!/usr/bin/env nextflow

INPUT_CH = Channel.from([[
  file(params.output.folder+ '/format/h5ad/data.h5ad'), 
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

process SCANPY_FILTER_CELLS_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/scanpy-scripts:0.2.4.post4--py_0"

  input:
    set file('data.h5ad'), val(ppid) from INPUT_CH

  output:
   file 'adata.h5ad' SCANPY_FILTER_CELLS_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
    scanpy-cli filter
    echo "scanpy filter subset_names=${subset_names} low_threshold=${low_threshold} high_threshold=${high_threshold} cells_use=${cells_use}" >> ${ppid +'-'+ pid}.txt
  """
    
}
