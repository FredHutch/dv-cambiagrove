#!/usr/bin/env nextflow


INPUT_CH = Channel.from([[
  file(params.input.h5ad), UUID.randomUUID().toString().substring(0,7)
]])

process ANNDATA_LOAD_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/scanpy-scripts:0.2.4.post4--py_0"
  echo true

  input:
    set file('adata.h5ad'),val(ppid) from INPUT_CH
    
  output:
   set file ('adata.h5ad'), file("${ppid +'-'+ pid}.txt"), val(pid) into SCANPY_FILTER_CELLS_CH
    //set file("${ppid +'-'+ pid}.txt")

  script:
    pid = UUID.randomUUID().toString().substring(0,7)
 

  """
  echo 'import scanpy as sc' >> temp.py
  echo 'adata = sc.read("adata.h5ad")' >> temp.py
  echo 'adata.var_names_make_unique()' >> temp.py
  echo 'adata.write("adata.h5ad")'>> temp.py
  python3 temp.py
  echo "AnnData Load. Make Var Names Unique." >> ${ppid +'-'+ pid}.txt
  """
}

process SCANPY_FILTER_CELLS_PR {
 publishDir "$params.output.folder"
  container "quay.io/biocontainers/scanpy-scripts:0.2.2--py_0"
  echo true

input:
    set file("adata.h5ad"),file("ledger.txt"), val(ppid) from SCANPY_FILTER_CELLS_CH
    each method from params.scanpy.filter_cells
    each min_counts from params.scanpy.filter_cells.min_counts
    each min_genes from params.scanpy.filter_cells.min_genes
    each max_counts from params.scanpy.filter_cells.max_counts
    each max_genes from params.scanpy.filter_cells.max_genes
    

output:
    set file("data.h5ad"), file("ledger.txt"),  val(pid) into SCANPY_FILTER_GENES_CH 

  script:
    pid = UUID.randomUUID().toString().substring(0,7)

"""
  LANG=en_US.UTF-8 scanpy filter-cells -i adata.h5ad -p n_genes,n_counts \
    -l ${params.scanpy.filter_cells.min_genes},${params.scanpy.filter_cells.min_counts} \
    -j ${params.scanpy.filter_cells.max_genes},${params.scanpy.filter_cells.max_counts} \
    -o "data.h5ad"

"""
// echo "scanpy method=\$scanpy min_counts=${min_counts} min_genes=${min_genes} 
// max_counts=${max_counts} max_genes=${max_genes}" >> ${ppid +'-'+ pid}.txt
}



//process SCANPY_FILTER_GENES_PR {
 //publishDir "$params.output.folder"
  //container "quay.io/biocontainers/scanpy-scripts:0.2.4.post4--py_0"
  //echo true

//input:
    //set file('data.h5ad'),val(ppid) from SCANPY_FILTER_GENES_CH
   // each method from params.scanpy.SCANPY_FILTER_GENES_CH   
    //each min_counts from params.scanpy.filter_cells.min_counts
    //each min_genes from params.scanpy.filter_cells.min_genes
    //each max_cells from params.scanpy.filter_cells.max_cells
    //each max_counts from params.scanpy.filter_cells.max_counts

//output:
    //set file("${ppid + '-' + pid}.h5ad"), file("${ppid +'-'+ pid}.txt"), val(pid) into SCANPY_FILTER_GENES_CH

  //script:
    //pid = UUID.randomUUID().toString().substring(0,7)

//"""
    //scanpy-filter-cells.py -i ${rawData} -p n_genes,n_counts \
    //-l ${params.scanpy.filter_cells.min_genes},${params.scanpy.filter_cells.min_counts} \
   // -j ${params.scanpy.filter_cells.max_genes},${params.scanpy.filter_cells.max_counts} \
    //-o ${matrix_name}_filter_cells.h5ad
//"""

//}

/*
process SCANPY_NORMALIZE_DATA_PR {
    """
    """

}

process SCANPY_FIND_VARIABLE_GENES_PR {
    """
    """
}

process SCANPY_SCALE_PR {
    """
    """
}
process SCANPY_REGRESS_PR {
    """
    """
}

process SCANPY_RUN_PCA_PR {
    """
    """
}

process SCANPY_NEIGHBORS_PR {
    """
    """
}
process SCANPY_RUN_TSNE_PR {
    """
    """
}

process SCANPY_RUN_UMAP_PR {
    """
    """
}

process SCANPY_FIND_CLUSTERS_PR {
    """
    """
}
process SCANPY_FIND_MARKERS_PR {
    """
    """
}
*/