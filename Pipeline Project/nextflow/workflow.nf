INPUT_CH = Channel.from([[
  file("s3://vis.fredhutch.singlecell.pipeline/data/row.rds")
]]);


process TENX_LOAD_PR {

  publishDir "s3://vis.fredhutch.singlecell.pipeline/data/results/"
  container "quay.io/biocontainers/monocle3-cli:0.0.3--py37r36hc9558a2_1"

  input:
    file "cds.rds"  from INPUT_CH

  output:
    file "test.txt" into MONOCLE3_EXTRACT_DIMS_CH

  """
  echo "HI" > test.txt
  """
}