# Dynamic Properties:
# - Embeddings - cores 
# - Embeddings - preprocess_method 
# - Clusters - reduction_method
# - markers - cores

library(monocle3)
library(jsonlite)

# Functions To Save Artifacts
saveGraph <- function(g,filename){
  print(c("SAVE GRAPH: ", filename))
  graph <- list()
  graph$edges <- as_data_frame(g, what = "edges")
  graph$vertices <- as_data_frame(g, what="vertices")
  row.names(graph$vertices) <- NULL
  if(ncol(graph$vertices)==0) graph$vertices <- NULL
  graph$directed <- is.directed(g)
  graph$name <- g$name
  json.content <- toJSON(graph, pretty=TRUE)
  if(!missing(filename)) {
    sink(filename)
    cat(json.content)
    sink()
  }
  return(json.content)
}

saveMatrix <- function(m, filename){
  print(c("SAVE MATRIX: ", filename))
  write.csv2(m, filename)
}

saveList <- function(l, filename){
  print(c("SAVE LIST: ", filename))
  write.csv2(l, filename)
}

# Functions To Test Pipeline
testLoadConfig <- function() {
  # Load Config
  json <- '{
    "datasources": [{
      "library": "MONOCLE3",
      "name": "CAO-L2",
      "config": {
        "type": "RDS",
        "expression_matrix": "http://staff.washington.edu/hpliner/data/cao_l2_expression.rds",
        "column_metadata": "http://staff.washington.edu/hpliner/data/cao_l2_colData.rds",
        "row_metadata": "http://staff.washington.edu/hpliner/data/cao_l2_rowData.rds"
      }
    },{
      "library": "MONOCLE3",
      "name": "PACKER-EMBRYO",
      "config": {
        "type": "RDS",
        "expression_matrix": "http://staff.washington.edu/hpliner/data/packer_embryo_expression.rds",
        "column_metadata": "http://staff.washington.edu/hpliner/data/packer_embryo_colData.rds",
        "row_metadata": "http://staff.washington.edu/hpliner/data/packer_embryo_rowData.rds"
      }
    }],
    "preprocess": [{
      "library": "MONOCLE3",
      "name": "PCA-100",
      "config": {
        "method": "PCA",
        "numDim": 100,
        "normMethod": "log",
        "genes": null,
        "residual_model_formula_str": null,
        "pseudoCount": 1,
        "scaling": true
      }
    },{
      "library": "MONOCLE3",
      "name": "PCA-200",
      "config": {
        "method": "PCA",
        "numDim": 200,
        "normMethod": "log",
        "genes": null,
        "residual_model_formula_str": null,
        "pseudoCount": 1,
        "scaling": true
      }
    }],
    "reductions": [{
      "library": "MONOCLE3",
      "name": "UMAP-2D",
      "config": {
        "max_components": 2,
        "reduction_method": "UMAP",
        "preprocess_method": "PCA",
        "umap.metric": "cosine",
        "umap.min_dist": 0.1,
        "umap.n_neighbors": 15,
        "umap.fast_sgd": true,
        "umap.nn_method": "annoy"
      }
    },{
      "library": "MONOCLE3",
      "name": "UMAP-3D",
      "config": {
        "max_components": 3,
        "reduction_method": "UMAP",
        "preprocess_method": "PCA",
        "umap.metric": "cosine",
        "umap.min_dist": 0.1,
        "umap.n_neighbors": 15,
        "umap.fast_sgd": true,
        "umap.nn_method": "annoy"
      }
    }],
    "clusters": [{
      "library": "MONOCLE3",
      "name": "UMAP",
      "config": {
        "reduction_method": "UMAP",
        "k": 20,
        "louvain_iter": 1,
        "partition_qval": 0.05,
        "weight": false,
        "resolution": null,
        "random_seed": 0
      }
    }],
    "markers": [{
      "library": "MONOCLE3",
      "name": "MARKERS",
      "config": {
        "group_cells_by": "partition",
        "genes_to_test_per_group": 25, 
        "reduction_method": "UMAP",
        "marker_sig_test": true, 
        "reference_cells": null
      }
    }],
    "graphs": [{
      "library": "MONOCLE3",
      "name": "GRAPH",
      "config": {
        "use_partition": true,
        "close_loop": true,
        "learn_graph_control": null
      }
    }], 
    "deployments": [{
      "library": "AWS",
      "name": "WEBSITE",
      "config": {
        "bucket": "s3://viz.fredhutch.org/datasets/test"
      }
    }],
    "pipeline": [{
        "datasource": "PACKER-EMBRYO",
        "preprocess": "PCA-100",
        "reduce": "UMAP-2D",
        "cluster": "UMAP",
        "marker": "MARKERS",
        "graph" : "GRAPH",
        "deployment": "WEBSITE"
    }]
  }'
  return(jsonlite::parse_json(json))
}

testRun <- function(){
  config <- testLoadConfig()
  for (pipeline in config$pipeline){
    for (datasource in config$datasources) {
      if (datasource$name == pipeline$datasource) {
        cds <- stepDatasource(datasource$config)
      }
    }
    for (preprocess in config$preprocess) { 
      if (preprocess$name == pipeline$preprocess){
        cds <- stepPreprocess(cds, preprocess$config, preprocess$name)
      }
    }
    for (reduction in config$reductions) { 
      if (reduction$name == pipeline$reduce){
        cds <- stepReduce(cds, reduction$config, reduction$name)
      }
    }
    for (cluster in config$clusters) { 
      if (cluster$name == pipeline$cluster){
        cds <- stepCluster(cds, cluster$config, cluster$name)
      }
    }
    for (marker in config$markers) { 
      if (marker$name == pipeline$marker){
        cds <- stepMarker(cds, marker$config, marker$name)
      }
    }
    for (graph in config$graphs) { 
      if (graph$name == pipeline$graph){
        cds <- stepGraph(cds, graph$config, graph$name)
      }
    }
  }
}

# Functions To Process Steps
stepDatasource <- function(stepConfig) {
  print("DATASOURCE")
  expression_matrix <- readRDS(url(stepConfig$expression_matrix))
  cell_metadata <- readRDS(url(stepConfig$column_metadata))
  gene_annotation <- readRDS(url(stepConfig$row_metadata))
  return(new_cell_data_set(expression_matrix, cell_metadata = cell_metadata, gene_metadata = gene_annotation))

}
stepPreprocess <- function(cds, stepConfig, stepName){
  print("PREPROCESS")
  stepConfig$cds <- cds
  cds <- do.call(preprocess_cds, stepConfig)
  saveMatrix(reducedDim(cds, type=stepConfig$method), paste("pp_",stepName, "_scores.csv", sep=""))
  saveMatrix(cds@preprocess_aux$gene_loadings, paste("pp_",stepName, "_loadings.csv", sep=""))
  saveList(cds@preprocess_aux$prop_var_expl, paste("pp_", stepName, "_varexpl.csv", sep=""))
  return(cds)
}

stepReduce <- function(cds, stepConfig, stepName){
  print("REDUCE")
  stepConfig$cds <- cds
  cds <- do.call(reduce_dimension, stepConfig)
  saveMatrix(reducedDim(cds, type=stepConfig$reduction_method), paste("dr_",stepName, "_scores.csv", sep=""))
  return(cds)
}

stepCluster <- function(cds, stepConfig, stepName){
  print("CLUSTER")
  stepConfig$cds <- cds
  cds <- do.call(cluster_cells, stepConfig)
  saveMatrix(cds@clusters@listData[[stepConfig$reduction_method]][["partitions"]], paste("cl_", stepName, "_partitians.csv", sep=""))
  saveMatrix(cds@clusters@listData[[stepConfig$reduction_method]][["clusters"]], paste("cl_", stepName, "_clusters.csv", sep=""))
  saveGraph(cds@clusters@listData[[stepConfig$reduction_method]][["louvain_res"]][["g"]], paste("cl_", stepName, "_graph.json", sep=""))
  return(cds)
}

stepMarker <- function(cds, stepConfig, stepName){
  print("MARKER")
  stepConfig$cds <- cds
  markers <- do.call(top_markers, stepConfig)
  saveMatrix(markers, paste("mk_", stepName, "_markers.csv", sep=""))
  return(cds)
}

stepGraph <- function(cds, stepConfig, stepName){
  print("GRAPH")
  stepGraph <- cds
  cds <- do.call(learn_graph, stepConfig)
  saveGraph(cds@principal_graph@listData[["UMAP"]], paste("gr_", stepName, "_principle.json", sep=""))
  return(cds)
}

# Kick It Off
testRun()