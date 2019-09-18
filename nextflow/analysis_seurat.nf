#!/usr/bin/env nextflow

INPUT_CH = Channel.from([[
  file(params.output.folder+ '/format/cds3/data.rds'), 
  UUID.randomUUID().toString().substring(0,7)
]])