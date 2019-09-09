// pyspark --driver-memory 8g
df = sqlContext.read.json('hgnc.json')
df.write.parquet("hgnc.parquet")