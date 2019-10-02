if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install()

# Tell R to also check bioconductor when installing dependencies
setRepositories(ind=1:2)

# Install Signac
install.packages("devtools")
