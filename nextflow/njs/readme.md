docker build -t nodeflow .
docker run nodeflow node --version // Test
docker login // To Docker Hub
docker tag nodeflow zager/nodeflow:1
docker push zager/nodeflow:1