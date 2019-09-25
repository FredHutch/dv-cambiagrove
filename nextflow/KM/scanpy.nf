#!/usr/bin/env nextflow


INPUT_CH = Channel.from([[
  file(params.input.row), 
  file(params.input.col), 
  file(params.input.exp), 
  UUID.randomUUID().toString().substring(0,7)
]])

INPUT_CH.into {
  ANNDATA_INPUT
}

process ANNDATA_LOAD {

  publishDir "$params.output.folder"
  container "quay.io/biocontainers/seurat-scripts:0.0.5--r34_1"

  input:
    set file('exp.rds'), file('col.rds'), file('row.rds'), val(ppid) from ANNDATA_INPUT

  output:
    set file('matrix.mtx'), file('barcodes.tsv'), file('cells.tsv'), file('genes.tsv'), val(pid) into ANNDATA_LOAD

  script:
    pid = UUID.randomUUID().toString().substring(0,7) 

  """
  echo "HELLO" > test.txt
  """
}

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