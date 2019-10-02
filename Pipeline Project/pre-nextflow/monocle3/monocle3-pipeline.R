# Dynamic Properties:
# - Embeddings - cores 
# - Embeddings - preprocess_method 
# - Clusters - reduction_method
# - markers - cores

library(igraph)
library(monocle3)
library(jsonlite)

get_earliest_principal_node <- function(cds, time_bin="130-170"){
  cell_ids <- which(colData(cds)[, "embryo.time.bin"] == time_bin)

  closest_vertex <-
    cds@principal_graph_aux[["UMAP"]]$pr_graph_cell_proj_closest_vertex
  closest_vertex <- as.matrix(closest_vertex[colnames(cds), ])
  root_pr_nodes <-
    igraph::V(principal_graph(cds)[["UMAP"]])$name[as.numeric(names
      (which.max(table(closest_vertex[cell_ids,]))))]

  root_pr_nodes
}

# Functions To Save Artifacts
saveGraph <- function(g,filename){
  filename <- tolower(paste(filename, '.graph.json', sep=""))
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
  filename <- tolower(paste(filename, '.matrix.csv', sep=""))
  print(c("SAVE MATRIX: ", filename))
  write.csv2(m, filename)
}

saveList <- function(l, filename){
  filename <- tolower(paste(filename, '.list.csv', sep=""))
  print(c("SAVE LIST: ", filename))
  write.csv2(l, filename)
}

# Functions To Test Pipeline
testLoadConfig <- function() {
  # Load Config
  json <- '{
    "datasources": [{
      "docker": "mzager/monocle3",
      "name": "CAO-L2",
      "config": {
        "type": "RDS",
        "expression_matrix": "http://staff.washington.edu/hpliner/data/cao_l2_expression.rds",
        "column_metadata": "http://staff.washington.edu/hpliner/data/cao_l2_colData.rds",
        "row_metadata": "http://staff.washington.edu/hpliner/data/cao_l2_rowData.rds"
      }
    },{
      "docker": "mzager/monocle3",
      "name": "PACKER-EMBRYO",
      "config": {
        "type": "RDS",
        "expression_matrix": "http://staff.washington.edu/hpliner/data/packer_embryo_expression.rds",
        "column_metadata": "http://staff.washington.edu/hpliner/data/packer_embryo_colData.rds",
        "row_metadata": "http://staff.washington.edu/hpliner/data/packer_embryo_rowData.rds"
      }
    }],
    "preprocess": [{
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
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
      "docker": "mzager/monocle3",
      "name": "GRAPH",
      "config": {
        "use_partition": true,
        "close_loop": true,
        "learn_graph_control": null
      }
    }],
    "trajectories":[{
      "docker": "mzager/monocle3",
      "name": "TRAJECTORY",
      "config":{
        "time_bin": "130-170",
        "reduction_method": "UMAP", 
        "root_pr_nodes": null,
        "root_cells": null
      }
    }], 
    "pipeline": [{
        "datasource": "PACKER-EMBRYO",
        "preprocess": "PCA-100",
        "reduce": "UMAP-2D",
        "cluster": "UMAP",
        "marker": "MARKERS",
        "graph" : "GRAPH",
        "trajectory": "TRAJECTORY"
    }]
  }'
  return(jsonlite::parse_json(json))
}

testRun <- function(){
  config <- testLoadConfig()
  cds <- NULL
  for (pipeline in config$pipeline){
    for (datasource in config$datasources) {
      if (datasource$name == pipeline$datasource) {
        cds <- stepDatasource(datasource$config, datasource$name)
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
    for (trajectory in config$trajectories) { 
      if (trajectory$name == pipeline$trajectory){
        cds <- stepTrajectory(cds, trajectory$config, trajectory$name)
      }
    }
  }
  return(cds)
}

# Functions To Process Steps
stepDatasource <- function(stepConfig, stepName) {
  print("DATASOURCE")
  expression_matrix <- readRDS(url(stepConfig$expression_matrix))
  cell_metadata <- readRDS(url(stepConfig$column_metadata))
  gene_annotation <- readRDS(url(stepConfig$row_metadata))
  cds <- new_cell_data_set(expression_matrix, cell_metadata = cell_metadata, gene_metadata = gene_annotation)
  saveMatrix(rowData(cds), paste("datasource-",stepName,"-row_data"))
  saveMatrix(colData(cds), paste("datasource-",stepName,"-col_data"))
  return(cds)

}
stepPreprocess <- function(cds, stepConfig, stepName){
  print("PREPROCESS")
  stepConfig$cds <- cds
  cds <- do.call(preprocess_cds, stepConfig)
  # Plot PCA Scores
  saveMatrix(reducedDim(cds, type=stepConfig$method), paste("preprocess-",stepName, "-dims", sep=""))
  # Plot PCA Loadings
  saveMatrix(cds@preprocess_aux$gene_loadings, paste("preprocess-",stepName, "-loadings", sep=""))
  # Plot Variance Explained
  saveList(cds@preprocess_aux$prop_var_expl, paste("preprocess-", stepName, "-variance_explained", sep=""))
  return(cds)
}

stepReduce <- function(cds, stepConfig, stepName){
  print("REDUCE")
  stepConfig$cds <- cds
  cds <- do.call(reduce_dimension, stepConfig)
  # Plot Dimension Reduction
  saveMatrix(reducedDim(cds, type=stepConfig$reduction_method), paste("reducedim-",stepName, "-dims", sep=""))
  return(cds)
}

stepCluster <- function(cds, stepConfig, stepName){
  print("CLUSTER")
  stepConfig$cds <- cds
  cds <- do.call(cluster_cells, stepConfig)
  # Color Cells
  saveMatrix(cds@clusters@listData[[stepConfig$reduction_method]][["partitions"]], paste("cluster-", stepName, "-partitions", sep=""))
  # Color Cells
  saveMatrix(cds@clusters@listData[[stepConfig$reduction_method]][["clusters"]], paste("cluster-", stepName, "-clusters", sep=""))
  # Draw Trajectory
  saveGraph(cds@clusters@listData[[stepConfig$reduction_method]][["louvain_res"]][["g"]], paste("cluster-", stepName, "-louvain", sep=""))
  return(cds)
}

stepMarker <- function(cds, stepConfig, stepName){
  print("MARKER")
  stepConfig$cds <- cds
  markers <- do.call(top_markers, stepConfig)
  # Data Grid of Markers / Color Cells
  saveMatrix(markers, paste("marker-", stepName, sep=""))
  return(cds)
}

stepGraph <- function(cds, stepConfig, stepName){
  print("GRAPH")
  stepConfig$cds <- cds
  cds <- do.call(learn_graph, stepConfig)
  # Draw Trajectory
  saveGraph(cds@principal_graph@listData[["UMAP"]], paste("graph-", stepName, "-principle", sep=""))
  return(cds)
}

stepTrajectory <- function(cds, stepConfig, stepName){
  print("TRAJECTORY")
  if (!is.null(stepConfig$time_bin)) {
    stepConfig$root_pr_nodes <- get_earliest_principal_node(cds, stepConfig$time_bin)
  }
  stepConfig$time_bin <- NULL
  stepConfig$cds <- cds
  cds <- do.call(order_cells, stepConfig)
  # Draw Trajectory
  saveGraph(cds@principal_graph_aux[['UMAP']]$pr_graph_cell_proj_tree, paste("trajectory-", stepName, "-pr_graph_cell_proj_tree", sep=""))
  # Not sure - There are other props here to investigate
  saveMatrix(cds@principal_graph_aux[['UMAP']]$dp_mst, paste("trajectory-", stepName, "-dp_mst"))
  return(cds)
}

# Kick It Off
setwd('/Users/zager/Desktop/delme')
cds <- testRun()