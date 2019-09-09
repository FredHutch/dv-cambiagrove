df = sqlContext.read.json('msigdb_v7.0.JSON')
df.write.parquet("msigdb_v7.0.parquet")