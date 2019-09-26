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
        if (prefix.equals("json")) {
          INPUT_JSOM_CH << [folderpath, foldername, item.name, item]
        }
        if (prefix.equals("attr")) {
          INPUT_ATTR_CH << [folderpath, foldername, item.name, item]
        }
    }

    """
    echo "Proxy for saving and forking - Nothing to execute"
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
  let obs = 0;
  let liner = new lineByLine(`mtx.csv`);
  liner.next(); // Column Names
  const data = [];
  while ((line = liner.next())) {
    const values = line.toString().split(",").map(parseFloat)
    if (obs !== values[0]) {

      // Write File
      const buffer = new ArrayBuffer( values.length * Float32Array.BYTES_PER_ELEMENT );
      const dataView = new DataView(buffer);
      values.foreach( (v, i) => { 
        dataView.setFloat32(i * Float32Array.BYTES_PER_ELEMENT, v, true);
      });
      fs.writeFileSync("obs_"+obs.toString()+".bin", new Uint8Array(dataView.buffer) );
      // Clear Array
      data.length = 0;
      obs = values[0];
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
    file 'attr_*'

  """
  #!node
  const fs = require('fs');
  const lineByLine = require('/usr/src/app/node_modules/n-readlines');
  let line;
  let lineNumber = 0;
  let columns;
  let columnCount;
  let data;
  let columnNames;
  let liner = new lineByLine(`attr.csv`);
  columnNames = liner
    .next()
    .toString()
    .split(',')
    .map(v => v.trim().toLowerCase());
  columnNames[0] = 'id';
  columns = new Array(columnNames.length);
  columnCount = columns.length;
  for (var i = 0; i < columns.length; i++) {
    columns[i] = new Set([]);
  }
  while ((line = liner.next())) {
    // Loop Through Data + Populate Columns Object
    // At End Of Loop If Columns Have < 255 Values They Will Be Populated, otherwise consider value discrete
    data = line
      .toString()
      .split(',')
      .map(v => v.toLowerCase().trim());
    for (var i = 0; i < columnCount; i++) {
      if (columns[i].size < 256) {
        columns[i].add(data[i]);
      }
    }
    lineNumber++;
  }
  let columnMetadata = new Array(columnCount);
  let discreteColumnIndexes = [];
  let numericColumnIndexes = [];
  let stringColumnIndexes = [];
  for (var i = 0; i < columnCount; i++) {
    if (columns[i].size <= 255) {
      columnMetadata[i] = Array.from(columns[i]);
      discreteColumnIndexes.push(i);
    } else {
      columnMetadata[i] = Array.from(columns[i]).reduce((isNumeric, c) => {
        if (isNaN(c)) {
          isNumeric = false;
        }
        return isNumeric;
      }, true)
        ? 'NUMERIC'
        : 'STRING';
      if (columnMetadata[i] === 'NUMERIC') {
        numericColumnIndexes.push(i);
      }
      if (columnMetadata[i] === 'STRING') {
        stringColumnIndexes.push(i);
      }
    }
  }
  const recordCount = lineNumber;

  // String Values
  if (stringColumnIndexes.length > 0) {
    stringColumnIndexes.forEach(columnIndex => {
      let filename = '${filename}';
      filename = 
        filename.substring(0, filename.length - 4) +
        '_string_' +
        columnNames[columnIndex] +
        '_' +
        recordCount +
        '.txt';
      let writeStream = fs.createWriteStream(filename);
      liner = new lineByLine(`attr.csv`);
      liner.next();
      while ((line = liner.next())) {
        const data = line
          .toString()
          .split(',')
          .map(v => v.toLowerCase().trim())[columnIndex];
        writeStream.write(data + '\\n', 'UTF8');
      }
      writeStream.end();
    });
  }

  // Numeric Values
  if (numericColumnIndexes.length > 0) {
    numericColumnIndexes.forEach(columnIndex => {
      let filename = '${filename}';
      filename = filename.substring(0, filename.length - 4) +
        '_number_' +
        columnNames[columnIndex] +
        '_' +
        recordCount +
        '.txt';
      let writeStream = fs.createWriteStream(filename);
      liner = new lineByLine(`attr.csv`);
      liner.next();
      while ((line = liner.next())) {
        const data = line
          .toString()
          .split(',')
          .map(v => v.toLowerCase().trim())[columnIndex];
        writeStream.write(data + '\\n', 'UTF8');
      }
      writeStream.end();
    });
  }

  // Write Indexes Of All Discrete Data Fields In Serial File 'observations_of_features'
  if (discreteColumnIndexes.length > 0) {
    const buffer = new ArrayBuffer(
      discreteColumnIndexes.length * recordCount * Uint8Array.BYTES_PER_ELEMENT
    );
    const dataView = new DataView(buffer);
    lineNumber = 0;
    liner = new lineByLine(`attr.csv`);
    liner.next();

    while ((line = liner.next())) {
      data = line
        .toString()
        .split(',')
        .map(v => v.toLowerCase().trim());

      discreteColumnIndexes.forEach((columnIndex, index) => {
        index = recordCount * index + lineNumber;
        const rowValue = data[columnIndex];
        const columnValues = columnMetadata[columnIndex];
        dataView.setUint8(
          index * Uint8Array.BYTES_PER_ELEMENT,
          columnValues.indexOf(rowValue),
          true
        );
      });
      lineNumber += 1;
    }

    filename = '${filename}';
    filename = filename.substring(0, filename.length - 4) +
      '_discrete_' +
      discreteColumnIndexes.length +
      '_of_' +
      recordCount +
      '.bin';

    fs.writeFileSync(filename, new Uint8Array(dataView.buffer));
  }
  process.exit(0);
  """
}