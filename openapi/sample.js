var YAML = require('json2yaml');
var fs = require('fs');
/*
get
  /annotation/{source}/{table}/schema/{schema}/{format}
  'annotation' - Forks Urls To allow For Other Bases Like Compute
  {source} === Table Prefix In Data Catalog (What Appears Before the first underscore: ncbi, alliancegenome, etc)
  {table} === Table Suffix in Data Calalog (What Appears After the 1st underscore: geneinfo)
  {schema} === One of the return swagger schemas - will map to the return fields / where clause
  {format} === Enum of CSV | JSON | XML | HTML

post
  /annotation/{source}/{table}/schema/{schema}/{format}
  'annotation' - Forks Urls To allow For Other Bases Like Compute
  {source} === Table Prefix In Data Catalog (What Appears Before the first underscore: ncbi, alliancegenome, etc)
  {table} === Table Suffix in Data Calalog (What Appears After the 1st underscore: geneinfo)
  {schema} === One of the return swagger schemas - will map to the return fields / where clause
  {format} === Enum of CSV | JSON | XML | HTML
  POST: {where} === Post Clause
  POST: {fields} == Array of Fields

Schema - terse | verbose | custom (post only)
*/

const openapi = {
  openapi: '3.0.1',
  info: {
    title: 'Data Visualization Initative Annotation Service',
    description:
      'This service was create to enable the rapid development of data visualizations at the Fred Hutchinson.',
    termsOfService: 'http://swagger.io/terms/',
    contact: {
      email: 'viz@fredhutch.oeg'
    },
    // license: {
    //   name: 'Apache 2.0',
    //   url: 'http://www.apache.org/licenses/LICENSE-2.0.html'
    // },
    version: '1.0.0'
  },
  externalDocs: {
    description:
      'Find out more about the Fred Hutch Data Visualization Initiative',
    url: 'http://viz.fredhutch.org/'
  },
  servers: [
    {
      url: 'http://viz.fredhutch.org/api'
    }
  ],
  paths: [],
  components: {
    schemas: {}
  }
};

getType = type => {
  switch (type) {
    case 'array<string>':
      return { type: 'array', items: { type: 'string' } };
    case 'array<bigint>':
      return { type: 'array', items: { type: 'integer', format: 'int64' } };
    case 'bigint':
      return { type: 'integer', format: 'int64' };
    default:
      return { type: type };
  }
};

// Load the SDK and UUID
var AWS = require('aws-sdk');
var uuid = require('node-uuid');

// Create Athena Clint
var athena = new AWS.Athena();
var glue = new AWS.Glue({ region: 'us-west-2' });

async function run() {
  let result = await glue
    .getTables({
      DatabaseName: 'reference'
    })
    .promise();

  let tbls = result;

  tbls = result.TableList.map(v => {
    var rv = {};
    const tblNameParts = v.Name.split('_');
    rv.source = tblNameParts.shift();
    rv.table = tblNameParts.join('_');
    rv.schemaRef = v.Name.toLowerCase();
    rv.schemaComponent = {
      type: 'object',
      properties: v.StorageDescriptor.Columns.reduce((p, c) => {
        p[c.Name] = getType(c.Type);
        return p;
      }, {})
    };
    return rv;
  });

  openapi.paths = tbls.reduce((p, c) => {
    const request = {
      tags: [c.source],
      summary: `${c.table.replace(/_/gi, ' ')} data from ${c.source.replace(
        /_/gi,
        ' '
      )}`,
      responses: {
        200: {
          description: 'successful operation',
          content: {
            'application/xml': {
              schema: {
                $ref: `#/components/schemas/${c.schemaRef}`
              }
            },
            'application/json': {
              schema: {
                $ref: `#/components/schemas/${c.schemaRef}`
              }
            }
          }
        },
        400: { description: 'Not Found', content: {} }
      }
    };
    p[`/annotation/${c.source}/${c.table}`] = { get: request, post: request };
    p[`/annotation/${c.source}/${c.table}/verbose`] = { get: request };
    return p;
  }, {});

  openapi.components.schemas = tbls.reduce((p, c) => {
    p[c.schemaRef] = c.schemaComponent;
    return p;
  }, {});

  // console.dir(schemas, { depth: '5' });
  const asYaml = YAML.stringify(openapi, 0, 10);
  fs.writeFileSync('schema.yaml', asYaml, 'UTF8');
}

run();
// // Create an S3 client
// var s3 = new AWS.S3();

// // Create a bucket and upload something into it
// var bucketName = 'node-sdk-sample-' + uuid.v4();
// var keyName = 'hello_world.txt';

// s3.createBucket({Bucket: bucketName}, function() {
//   var params = {Bucket: bucketName, Key: keyName, Body: 'Hello World!'};
//   s3.putObject(params, function(err, data) {
//     if (err)
//       console.log(err)
//     else
//       console.log("Successfully uploaded data to " + bucketName + "/" + keyName);
//   });
// });
