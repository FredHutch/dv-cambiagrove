var parser = require('xml2json');
var fs = require('fs');
var xmlString = fs.readFileSync('msigdb_v7.0.xml', 'UTF8');
var jsonString = parser.toJson(xmlString);
var data = JSON.parse(jsonString);
const genesets = data.MSIGDB.GENESET;
genesets.forEach(geneset => {
  [
    'AUTHORS',
    'TAGS',
    'MEMBERS',
    'MEMBERS_SYMBOLIZED',
    'MEMBERS_MAPPING',
    'MEMBERS_EZID'
  ].forEach(listProperty => {
    geneset[listProperty] = geneset[listProperty].split(',');
  });
});

fs.writeFileSync('msigdb_v7.0.json', JSON.stringify(genesets), 'utf8');
