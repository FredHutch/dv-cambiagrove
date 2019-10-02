docker build -t nodeflow .
docker run nodeflow node --version // Test
docker login // To Docker Hub
docker tag nodeflow zager/nodeflow:1
docker push zager/nodeflow:1


nextflow run import_rds.nf
nextflow run analysis_monocle3.nf
nextflow run export_monocle3.nf
nextflow run optimize_monocle3.nf



docker build -t scanpy .
docker run -ti scanpy bash
docker login // To Docker Hub
docker tag scanpy zager/scanpy:1
docker push zager/scanpy:1