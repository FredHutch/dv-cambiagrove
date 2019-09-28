#!/usr/bin/env nextflow

INPUT_CH = Channel
  .fromPath("$params.output.folder/analysis/monocle3/*.txt")
  .map { file -> tuple( "${file.parent}/${file.baseName}", file.baseName, file) }

INPUT_DR_CH = Channel.create();
INPUT_MTX_CH = Channel.create();
INPUT_JSON_CH = Channel.create();
INPUT_ATTR_CH = Channel.create();
INPUT_VE_CH = Channel.create(); 


process OPTIMIZE_FILES_PR {

  publishDir "$params.output.folder/optimize/$foldername"
  container "zager/nodeflow:1"

  input:
    set folderpath, foldername, file('ledger.txt') from INPUT_CH

  output:
    file('ledger.txt')

  script:
    file(folderpath).eachFile {
      item -> 
        String prefix = item.name.split("_")[0];
        if (prefix.equals("dr")) {
          INPUT_DR_CH << [folderpath, foldername, item.name, item]
        }
        if (prefix.equals("mtx")) {
          INPUT_MTX_CH << [folderpath, foldername, item.name, item]
        }
        if (item.name.equals('variance_explained.csv')) {
          INPUT_VE_CH << [folderpath, foldername, item.name, item]
        }
        if (prefix.equals("attr")) {
          INPUT_ATTR_CH << [folderpath, foldername, item.name, item]
        }
    }

    """
    echo "Proxy for saving and forking - Nothing to execute"
    """
}

process OPTIMIZE_VE_PR {
  publishDir "$params.output.folder/optimize/$foldername"
  container "zager/nodeflow:1"

  input:
    set folderpath, foldername, filename, file('variance_explained.csv') from INPUT_VE_CH
    
  output:
    file 'stat*'
  
  """
  #!node
  const fs = require('fs');
  let data = fs.readFileSync('variance_explained.csv', 'UTF8').split("\\n").map(v => v.split(","))
  const output = data.filter( (v,i) => {
    return !(i===0 || v.length ===1);
  }).map( v => v[1]).join(',');
  fs.writeFileSync('stat.variance_explained.csv', output, 'UTF8');

  """
}
process OPTIMIZE_MTX_PR {

  publishDir "$params.output.folder/optimize/$foldername/mtx"
  container "zager/nodeflow:1"

  input:
    set folderpath, foldername, filename, file('mtx.csv') from INPUT_MTX_CH

  output:
    file 'obs_*'

  """
  #!node
  const fs = require('fs');
  const lineByLine = require('/usr/src/app/node_modules/n-readlines');
  const bin = require('/usr/src/app/node_modules/d3-array').bin();
  let obs = 0;
  let liner = new lineByLine(`mtx.csv`);
  liner.next(); // Column Names
  const data = [];
  while ((line = liner.next())) {
    const values = line.toString().split(",").map(parseFloat)
    if (obs !== values[0]) {

      // Write File
      const buffer = new ArrayBuffer( data.length * Float32Array.BYTES_PER_ELEMENT );
      const dataView = new DataView(buffer);
      for (var i=0; i<data.length; i++) {
        dataView.setFloat32(i * Float32Array.BYTES_PER_ELEMENT, data[i], true);
      }
      fs.writeFileSync("obs_"+obs.toString()+".bin", new Uint8Array(dataView.buffer) );
      // Clear Array
      obs = values[0];
      data.length = 0;
      
    }
    data.push(values[1], values[2])
  }
  """
  
}

process OPTIMIZE_DR_PR {

  publishDir "$params.output.folder/optimize/$foldername"
  container "zager/nodeflow:1"

  input:
    set folderpath, foldername, filename, file('dr.csv') from INPUT_DR_CH

  output:
    file 'dr_*'

  """
  #!node
  const fs = require('fs');
  const lineByLine = require('/usr/src/app/node_modules/n-readlines');
  const createScale = (domainMin, domainMax, rangeMin, rangeMax) => {
    return value => {
      var value = Math.round(
        rangeMin +
          (rangeMax - rangeMin) * ((value - domainMin) / (domainMax - domainMin))
      );
      value = Math.max(value, rangeMin);
      value = Math.min(value, rangeMax);
      return value;
    };
  };
  const roundNumber = (num, dec) => { return Math.round(num * Math.pow(10, dec)) / Math.pow(10, dec); 
  }
  let buffer, dataview, liner, lineNumber;
  liner = new lineByLine(`dr.csv`);
  const columnNames = liner
    .next()
    .toString()
    .split(',');
  const columnCount = columnNames.length - 1;
  let dataMin = Infinity;
  let dataMax = -Infinity;
  lineNumber = 0;
  while ((line = liner.next())) {
    const values = line
      .toString()
      .split(',')
      .map(v => parseFloat(v));
    values.shift(); // Remove Identity Column
    dataMin = Math.min(dataMin, ...values);
    dataMax = Math.max(dataMax, ...values);
    lineNumber += 1;
  }
  const rowCount = lineNumber;
  const scale = createScale(dataMin, dataMax, -32768, 32767);

  // Write Raw Values
  liner = new lineByLine(`dr.csv`);
  liner.next(); // Column Names
  buffer = new ArrayBuffer(
    rowCount * columnCount * Float32Array.BYTES_PER_ELEMENT
  );
  dataView = new DataView(buffer);
  lineNumber = 0;
  while ((line = liner.next())) {
    values = line.toString().split(',');
    values.shift(); // ID Column
    values.forEach((value, index) => {
      value = roundNumber(parseFloat(value), 7);
      dataView.setFloat32(
        (lineNumber * columnCount + index) * Float32Array.BYTES_PER_ELEMENT,
        value,
        true
      );
    });
    lineNumber += 1;
  }
      filename = "${filename}";
      filename = filename.substring(
        0,
        filename.length - 4
      ) + "_raw_F32_" + rowCount + "_of_" + columnCount + ".bin";
      fs.writeFileSync(filename, new Uint8Array(dataView.buffer) );

      // Write Scaled 2D Values
      liner = new lineByLine(`dr.csv`);
      liner.next(); // Column Names
      buffer = new ArrayBuffer(rowCount * 2 * Int16Array.BYTES_PER_ELEMENT);
      dataView = new DataView(buffer);
      lineNumber = 0;
      while ((line = liner.next())) {
        values = line.toString().split(',');
        values.shift(); // ID Column
        values.forEach((value, index) => {
          if (index < 2) {
            value = scale(parseFloat(value));
            dataView.setInt16(
              (lineNumber * 2 + index) * Int16Array.BYTES_PER_ELEMENT,
              value,
              true
            );
          }
        });
        lineNumber += 1;
      }

      filename = "${filename}".substring(
        0,
        filename.length - 4
      ) + "_scale_I16_"+rowCount+"_of_2.bin";

      fs.writeFileSync(
        filename,
        new Uint8Array(dataView.buffer)
      );

      if (columnCount > 2) {
        // Write Scaled 3D Values
        liner = new lineByLine(`dr.csv`);
        liner.next(); // Column Names
        buffer = new ArrayBuffer(rowCount * 3 * Int16Array.BYTES_PER_ELEMENT);
        dataView = new DataView(buffer);
        lineNumber = 0;
        while ((line = liner.next())) {
          values = line.toString().split(',');
          values.shift(); // ID Column
          values.forEach((value, index) => {
            if (index < 3) {
              value = scale(parseFloat(value));
              dataView.setInt16(
                (lineNumber * 2 + index) * Int16Array.BYTES_PER_ELEMENT,
                value,
                true
              );
            }
          });
          lineNumber += 1;
        }
        filename = "${filename}".substring(
          0,
          filename.length - 4
        )+"_scale_I16_"+rowCount+"_of_3.bin";
        fs.writeFileSync(filename,
          new Uint8Array(dataView.buffer)
        );
      }
      process.exit(0);

  """

}

process OPTIMIZE_ATTR_PR {

  publishDir "$params.output.folder/optimize/$foldername"
  container "zager/nodeflow:1"

  input:
    set folderpath, foldername, filename, file('attr.csv') from INPUT_ATTR_CH

  output:
    file('attr_*')

  """
  #!node
  const fs = require('fs');
  const lineByLine = require('/usr/src/app/node_modules/n-readlines');
  const bin = require('/usr/src/app/node_modules/d3-array').bin()

  const DATA_TYPES = {
    DISCRETE: 'DISCRETE',
    NUMERIC: 'NUMERIC',
    IDENTITY: 'IDENTITY',
  }

  // Establish Columns With Identity Data Type
  let liner = new lineByLine(`attr.csv`); // Replace with attr.csv
  let columns = liner.next().toString().split(",").map((v, i) => (i == 0) ? 'id' : v.trim().toLowerCase()).map((v, i) => ({
    index: i,
    name: v,
    datatype: null,
    values: new Set([]),
    count: 0
  }));
  
  // Determine DataType + Populate Values 
  let rowCount = 0;
  while ((line = liner.next())) {
    rowCount += 1;
    line
      .toString()
      .split(',')
      .map(v => v.toLowerCase().trim())
      .forEach((v, i) => {
        // Store Upto 256 Values In Columns
        if (columns[i].values.size <= 256) {
          columns[i].values.add(v);
        }
      });
  }

  // Determine Data Types
  columns.forEach((v, i) => {
    // Even If Values Are Numeric - if values < 33 treat as discrete (why 33?  It's a magic number)
    const isNumeric = (columns[i].values.length < 33) ? false : Array.from(columns[i].values)
      .reduce((p, c, i) => {
        if (isNaN(c)) { p = false; }
        return p;
      }, true);
    if (isNumeric) {
      columns[i].datatype = DATA_TYPES.NUMERIC;
    } else {
      columns[i].datatype = (columns[i].values.size < 256) ?
        DATA_TYPES.DISCRETE : DATA_TYPES.IDENTITY;
    }
  });

  // Convert Discrete Value Sets Into Arrays
  columns.filter(v => v.datatype === DATA_TYPES.DISCRETE).forEach(column => {
    column.values = Array.from(column.values);
  });

  // Determine Min Max Of NUmeric Columns
  columns.filter(v => v.datatype === DATA_TYPES.NUMERIC).forEach(column => {
    column.values.clear();
    column.values = [];
    let liner = new lineByLine(`attr.csv`);
    liner.next();
    while ((line = liner.next())) {
      const value = parseFloat(line.toString().split(",")[column.index].toLowerCase().trim());
      column.values.push(value);
    }
    column.values = bin(column.values).map(v => ({ min: v.x0, max: v.x1 }))
  })

  // Write Discrete Values
  const discreteColumnCount = columns.filter(v => v.datatype !== DATA_TYPES.IDENTITY).length;
  const bffr = new ArrayBuffer(discreteColumnCount * rowCount * Uint8Array.BYTES_PER_ELEMENT)
  const dataView = new DataView(bffr);
  let row;
  columns.filter(v => v.datatype !== DATA_TYPES.IDENTITY).forEach((column, columnIndex) => {
    let liner = new lineByLine(`attr.csv`);
    liner.next();
    row = 0;
    while ((line = liner.next())) {
      let value = line.toString().split(",")[column.index].toLowerCase().trim();
      if (column.datatype === DATA_TYPES.DISCRETE) {
        dataView.setUint8(
          (row * discreteColumnCount) + columnIndex,
          column.values.indexOf(value),
          true
        );
      }
      if (columns.datatype === DATA_TYPES.NUMERIC) {
        //Get Index From Bin
        value = parseFloat(value);
        for (let i = 0; i < column.values.length; i++) {
          if (value >= column.values[i].min && value <= column.values[i].max) {
            dataView.setUint8(
              (row * discreteColumnCount) + column.index,
              i,
              true
            );
            break;
          }
        }
      }
      row += 1;
    }
    if (column.datatype === DATA_TYPES.NUMERIC) {
      column.values[0].min = Math.floor(column.values[0].min)
      column.values[column.values.length - 1].max = Math.ceil(column.values[column.values.length - 1].max)
      column.values = column.values.map(v => v.min + " - " + v.max);
    }
  });
  if (discreteColumnCount){
    filename = '${filename}';
    filename = filename.substring(0, filename.length - 4) +
    '_discrete_' + row + '_of_' + discreteColumnCount
    fs.writeFileSync(
      filename,
      new Uint8Array(dataView.buffer)
    );
    filename = '${filename}';
    filename = filename.substring(0, filename.length - 4) +
    '_discrete_labels.json'
    fs.writeFileSync(filename, JSON.stringify(
      columns.filter(v => v.datatype !== DATA_TYPES.IDENTITY).map( v => ({ field: v.name, data: v.datatype, values: v.values }) )
    ), 'UTF8')
  }

  columns.filter(v => v.datatype !== DATA_TYPES.DISCRETE).forEach((column, columnIndex) => {
    let liner = new lineByLine(`attr.csv`);
    liner.next();
    let output = '';
    while ((line = liner.next())) {
      let value = line.toString().split(",")[column.index].toLowerCase().trim();
      output += value + "\\n";
    }
    let filename = '${filename}';
    filename =
      filename.substring(0, filename.length - 4) + '.' +
      column.datatype.toLowerCase() + '.' +
      column.name.toLowerCase() + '.' +
      row +
      '.txt';
    fs.writeFileSync(filename, output, 'UTF8');
  });


  process.exit(0);
  """
}