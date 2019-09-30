
docker build -t seurat .
docker login // To Docker Hub
docker tag seurat zager/seurat:1
docker push zager/seurat:1