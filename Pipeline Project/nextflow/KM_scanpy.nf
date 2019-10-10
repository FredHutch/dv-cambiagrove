#!/usr/bin/env nextflow

INPUT_CH = Channel.from([[
  file(params.input.h5ad), UUID.randomUUID().toString().substring(0,7)
]])

process ANNDATA_LOAD_PR {

  publishDir "$params.output.folder"
  container "zager/scanpy:3"
  echo true

  input:
    set file('adata.h5ad'),val(ppid) from INPUT_CH
    each var_names from params.scanpy.read.var_names

  output:
   set file ('data.h5ad'), file("${ppid +'-'+ pid}.txt"), val(pid) into SCANPY_PCA_CH

  script:
    pid = UUID.randomUUID().toString().substring(0,7)
 

  """
  echo 'import scanpy as sc' >> temp2.py
  echo 'adata = sc.read("adata.h5ad")' >> temp2.py
  echo 'adata.var_names_make_unique()' >> temp2.py
  echo 'adata.write("data.h5ad")'>> temp2.py
  python3 temp2.py
  echo "AnnData Load. Make Var Names Unique." >> ${ppid +'-'+ pid}.txt 
  """

/* 
  Theortetically this should work: 
  scanpy-cli read -i adata.h5ad -F anndata data.h5ad -v ${var_names}
  echo "scanpy-cli read -i adata.h5ad -F anndata data.h5ad -v ${var_names}" >> ${ppid +'-'+ pid}.txt 
  */

}

process SCANPY_PCA_PR {
 publishDir "$params.output.folder"
  container "zager/scanpy:3"
  echo true

input:
    set file("adata.h5ad"),file("ledger.txt"), val(ppid) from SCANPY_PCA_CH
    each no_zero_center from params.scanpy.pca.no_zero_center
    each n_comps from params.scanpy.pca.n_comps
    each svd_solver from params.scanpy.pca.svd_solver
    each use_all from params.scanpy.pca.use_all

output:
    set file("data.h5ad"), file("${ppid +'-'+ pid}.txt"),  val(pid) into SCANPY_HVG_CH 

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

"""
scanpy-cli pca --no-zero-center --n-comps=${n_comps} --svd-solver=${svd_solver} --use-all -f anndata adata.h5ad -F anndata 'data.h5ad'
echo "scanpy-cli pca --no-zero-center --n-comps=${n_comps} --svd-solver=${svd_solver} --use-all" >> ${ppid +'-'+ pid}.txt
"""

}

process SCNANPY_HVG_PR {
  publishDir "$params.output.folder"
  container "zager/scanpy:3"
  echo true

input:
    set file("adata.h5ad"),file("ledger.txt"), val(ppid) from SCANPY_HVG_CH
    each min_mean_limit from params.scanpy.hvg.min_mean_limit
    each max_mean_limit from params.scanpy.hvg.max_mean_limit
    each min_disp_limit from params.scanpy.hvg.min_disp_limit
    each max_disp_limit from params.scanpy.hvg.max_disp_limit
    each subset from params.scanpy.hvg.subset
    each by_batch from params.scanpy.hvg.by_batch

output:
    set file("adata.h5ad"), file("${ppid +'-'+ pid}.txt"),  val(pid) into SCANPY_UMAP_CH 

script:
    pid = UUID.randomUUID().toString().substring(0,7)
    //might need splitting

"""
echo "pass through_function not yet working" >> ${ppid +'-'+ pid}.txt
"""
}