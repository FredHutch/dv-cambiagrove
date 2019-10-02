# AWS Glue

## Introduction

* [YouTube - What is AWS Glue?](https://www.youtube.com/watch?v=qgWMfNSN9f4&feature=youtu.be)
* [What is Glue?](https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html)
* [Key Concepts](https://docs.aws.amazon.com/glue/latest/dg/components-key-concepts.html)

## Getting Started

AWS Glue consists of basically 3 parts: a crawler, a data catalog, and ETL jobs.


## Data Catalog

The data catalog is just that: a catalog ('database') with a list of tables that can be queried/read/written to.
Each table contains information on where its data is stored (S3, a database, etc), its format, and its schema (column names + datatypes).

* [Getting Started with the Glue Data Catalog](https://www.youtube.com/watch?v=qNojanBn1NY&feature=youtu.be)

## Crawlers

New tables can be created in the data catalog using 'crawlers'. For example, let's say we have a bunch of CSV files in s3://public-example-bucket/aircraft-flights/ , one per airline. We could point the crawler at the folder and it would create a table for each of them. If all of the files had the same schema, it would probably create a single table for *all* of them combined (e.g. 'combining compatible schemas', or 'table grouping').

* [Defining Crawlers](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)

**STTR Note**

NCBI files are tab-delimited columnar files, stored as compressed (.gz) files. They're like a CSV file with tabs instead of commas.

The AWS crawler can read .gz files and infer the schema, so you don't need to decompress them. Makes it easy.


## ETL

ETL jobs in Glue are source-to-target jobs with transforms. The transforms are written in PySpark. For very simple transforms (e.g. 'copy a table from here to here & re-format it'), you can do this entirely in the AWS console, and not have to write any code.

* [Getting Started with AWS Glue ETL](https://www.youtube.com/watch?v=z3HeHlWg88M&feature=youtu.be)
* [Editing Scripts](https://docs.aws.amazon.com/glue/latest/dg/edit-script.html)
* [Using Python Libraries](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-python-libraries.html)
* [Sample Script - Join + Relationalize](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-python-samples-legislators.html)
* [Sample Script - Data Preparation](https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming-python-samples-medicaid.html)
* [How It Works](https://docs.aws.amazon.com/glue/latest/dg/how-it-works.html)

**STTR Viz Account**

Source data: ```s3://sttr-viz-ingestion/experiment/gene```
Destination: ```s3://sttr-viz-ingestion/glue-experiments```
Where to store code: ```s3://sttr-viz-ingestion/code/glue```

**PySpark**

* [A Brief Introduction to PySpark](https://towardsdatascience.com/a-brief-introduction-to-pyspark-ff4284701873)

Now, let's look at how to 

### gene2ensembl

The gene2ensemble data is stored at ```s3://sttr-viz-ingestion/experiment/gene/DATA/gene2accession.gz```

1. Point a crawler at that folder (```s3://sttr-viz-ingestion/experiment/gene/DATA```) and it will create tables for each of the .gz files in the data catalog
2. Go into the data catalog, find the ```gene2accession.gz``` table, and give it the proper column names. The crawler doesn't correctly read the first line of the file and figure out the column names on its own.
3. Create a Glue job, with the ```gene2accession.gz``` table as the source. Walk through the console wizard, defining a Parquet file as the target, and tell it to write to an appropriate S3 location (e.g. ```s3://sttr-viz-ingestion/glue-experiments```). 
   * Then run the job
4. Check the S3 destination to make sure the Parquet file has been created. 

This is just a copy, so it's possible to do in the UI without any coding at all.

### gene2accession

This works the same way as gene2ensembl, but the columns are different:

```#tax_id  GeneID   status   RNA_nucleotide_accession.version RNA_nucleotide_gi protein_accession.version  protein_gi  genomic_nucleotide_accession.version   genomic_nucleotide_gi   start_position_on_the_genomic_accession   end_position_on_the_genomic_accession  orientation assembly mature_peptide_accession.version mature_peptide_gi Symbol```


### Querying the Results

* We'll start with [AWS Athena](https://us-west-2.console.aws.amazon.com/athena/home?force&region=us-west-2#query). It connects to the Glue data catalog automatically, so you can query the data tables you've created.
   * For example, ```SELECT * FROM "ncbi"."output_ncbi" WHERE geneid = 31045;``` lets me find all the records with GeneID = 31045 in the gene2ensembl output (it was named 'output_ncbi' because I didn't know any better).

