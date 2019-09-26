#!/usr/bin/env nextflow


INPUT_CH = Channel.from([[
  file(params.input.exp),
  file(params.input.col),
  file(params.input.row), 
  UUID.randomUUID().toString().substring(0,7)
]])

process ANNDATA_LOAD_PR {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/scanpy-scripts:0.2.4.post4--py_0"

  input:
    set file('matrix.mtx'), file('genes.tsv'), file('barcodes.tsv'), val(ppid) from INPUT_CH

  output:
   file 'test2.txt'

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  dir=\$('matrix.mtx' | head -n1 | tr -s ' ' | cut -d' ' -f5- | sed 's|/||')
  scanpy-read-10x.py -d \${dir}/ -o matrix_raw.h5ad -F anndata

  """
    
}

//ANNDATA_LOAD_CH.into{
  //SCANPY_INPUT_CH
//}

// process read_10x {
    
//     //  change to container name? 
//     //conda "${workflow.projectDir}/envs/scanpy.yml"
//     container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"
//     // but different from the one above 

//     // path set in config file
//     publishDir "$params.output.folder"

//     // is this already specified for all processes in the config file?
//     memory { 2.GB * task.attempt }
//     errorStrategy { task.exitStatus == 130 || task.exitStatus == 137 ? 'retry' : 'finish' }
//     maxRetries 10

//     input:
//         file expressionMatrix from RAW_COUNT_MATRIX
        
//     output:
//         file "${matrix_name}_raw.h5ad" into RAW_ANNDATA

//     """
//         zipdir=\$(unzip -qql ${expressionMatrix.getBaseName()}.zip | head -n1 | tr -s ' ' | cut -d' ' -f5- | sed 's|/||')
//         unzip ${expressionMatrix.getBaseName()}
//         scanpy-read-10x.py -d \${zipdir}/ -o ${matrix_name}_raw.h5ad -F anndata
//     """
// }