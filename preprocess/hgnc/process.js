
//node --max-old-space-size=8192
var fs = require('fs');
var data = JSON.parse(fs.readFileSync('hgnc_complete_set.json', 'UTF8'));
fs.writeFileSync('hgnc.json', JSON.stringify(data.response.docs), 'utf8');
