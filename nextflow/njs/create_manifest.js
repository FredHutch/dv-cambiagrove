const fs = require('fs');
const _ = require('lodash');
const lineByLine = require('n-readlines');
const dataFolder = 'out/analysis/monocle3/';
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
function roundNumber(num, dec) {
  return Math.round(num * Math.pow(10, dec)) / Math.pow(10, dec);
}

const dataFiles = fs
  .readdirSync(dataFolder, 'utf8')
  .filter(file => file.endsWith('.txt'));

const analysis = dataFiles
  .map(fileName => ({
    name: fileName.substr(0, fileName.length - 4),
    contents: fs.readFileSync(dataFolder + fileName, 'UTF-8')
  }))
  .map(file => {
    // Each Data file Contains A List Of Commands
    const commands = file.contents.split('\n');
    // Each Command Starts With A Process + Step followed by Args
    const process = commands.reduce((p, c) => {
      const command = c.split(' ');
      if (command.length < 3) return p;
      p.library = command[0];
      p.step = p.step || [];
      p.step.push({
        fn: command[1],
        arg: command.reduce((p, c, i) => {
          if (i < 2) return p;
          var kv = c.split('=');
          p[kv[0]] = kv[1];
          return p;
        }, {})
      });
      return p;
    }, {});
    const files = fs.readdirSync(dataFolder + '/' + file.name);
    return { name: file.name, ...process, files: files };
  });
fs.writeFileSync(
  `${dataFolder}/manifest.json`,
  `{"manifest":${JSON.stringify(analysis)}}`,
  'UTF8'
);

// Export Dimensions
analysis.forEach(anali => {
  anali.files
    .filter(f => f.startsWith('dr_'))
    .forEach(file => {
      let buffer, dataview, liner, lineNumber;
      liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
      liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
      let filename = `${file.substring(
        0,
        file.length - 4
      )}_raw_F32_${rowCount}_of_${columnCount}.bin`;
      fs.writeFileSync(
        `${dataFolder}/${anali.name}/dv_${filename}`,
        new Uint8Array(dataView.buffer)
      );

      // Write Scaled 2D Values
      liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
      filename = `${file.substring(
        0,
        file.length - 4
      )}_scale_I16_${rowCount}_of_2.bin`;

      fs.writeFileSync(
        `${dataFolder}/${anali.name}/dv_${filename}`,
        new Uint8Array(dataView.buffer)
      );

      if (columnCount > 2) {
        // Write Scaled 3D Values
        liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
        filename = `${file.substring(
          0,
          file.length - 4
        )}_scale_I16_${rowCount}_of_3.bin`;
        fs.writeFileSync(
          `${dataFolder}/${anali.name}/dv_${filename}`,
          new Uint8Array(dataView.buffer)
        );
      }
    });
});

// Export Variance Explained
analysis.forEach(anali => {
  anali.files
    .filter(f => f === 'variance_explained.csv')
    .forEach(file => {
      let liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
      liner.next(); // Skip Column Names
      let writeStream = fs.createWriteStream(
        `${dataFolder}/${anali.name}/dv_qc_variance_explained.txt`
      );
      while ((line = liner.next())) {
        writeStream.write(line.toString().split(',')[1] + '\n', 'UTF8');
      }
      writeStream.end();
    });
});

// // Export Matrix
// analysis.forEach(anali =>
//   anali.files
//     .filter(f => f.startsWith('matrix'))
//     .forEach(file => {
//       let buffer, dataview, liner, lineNumber;
//       lineNumber = 0;
//       liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
//       liner.next(); // Skip Col Names
//       while ((line = liner.next())) {
//         lineNumber++;
//       }
//       const numRows = lineNumber;

//       liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
//       liner.next(); // Skip Col Names
//       buffer = new ArrayBuffer(numRows * 2 * Uint32Array.BYTES_PER_ELEMENT);
//       dataView = new DataView(buffer);
//       lineNumber = 0;
//       while ((line = liner.next())) {
//         line
//           .toString()
//           .split(',')
//           .map(v => parseInt(v))
//           .forEach((value, index) => {
//             if (index < 2) {
//               dataView.setUint32(
//                 (lineNumber * 2 + index) * Uint32Array.BYTES_PER_ELEMENT,
//                 value,
//                 true
//               );
//             }
//           });
//         lineNumber += 1;
//       }
//       filename = `${file.substring(
//         0,
//         file.length - 4
//       )}_rc_UI32_${lineNumber}_of_2.bin`;
//       fs.writeFileSync(
//         `${dataFolder}/${anali.name}/dv_${filename}`,
//         new Uint8Array(dataView.buffer)
//       );
//       console.log(lineNumber);
//     })
// );

// Export Annotations
analysis.forEach(anali =>
  anali.files
    .filter(f => f.startsWith('attr_'))
    .forEach(file => {
      let line;
      let lineNumber = 0;
      let columns;
      let columnCount;
      let data;
      let columnNames;
      let liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
          const filename =
            file.substring(0, file.length - 4) +
            '_string_' +
            columnNames[columnIndex] +
            '_' +
            recordCount +
            '.txt';
          let writeStream = fs.createWriteStream(
            `${dataFolder}/${anali.name}/dv_${filename}`
          );
          liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
          liner.next();
          while ((line = liner.next())) {
            const data = line
              .toString()
              .split(',')
              .map(v => v.toLowerCase().trim())[columnIndex];
            writeStream.write(data + '\n', 'UTF8');
          }
          writeStream.end();
        });
      }

      // Numeric Values
      if (numericColumnIndexes.length > 0) {
        numericColumnIndexes.forEach(columnIndex => {
          const filename =
            file.substring(0, file.length - 4) +
            '_number_' +
            columnNames[columnIndex] +
            '_' +
            recordCount +
            '.txt';
          let writeStream = fs.createWriteStream(
            `${dataFolder}/${anali.name}/dv_${filename}`
          );
          liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
          liner.next();
          while ((line = liner.next())) {
            const data = line
              .toString()
              .split(',')
              .map(v => v.toLowerCase().trim())[columnIndex];
            writeStream.write(data + '\n', 'UTF8');
          }
          writeStream.end();
        });
      }

      // Write Indexes Of All Discrete Data Fields In Serial File 'observations_of_features'
      if (discreteColumnIndexes.length > 0) {
        const buffer = new ArrayBuffer(
          discreteColumnIndexes.length *
            recordCount *
            Uint8Array.BYTES_PER_ELEMENT
        );
        const dataView = new DataView(buffer);
        lineNumber = 0;
        liner = new lineByLine(`${dataFolder}/${anali.name}/${file}`);
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
        const filename =
          file.substring(0, file.length - 4) +
          '_discrete_' +
          discreteColumnIndexes.length +
          '_of_' +
          recordCount +
          '.bin';

        fs.writeFileSync(
          `${dataFolder}/${anali.name}/dv_${filename}`,
          new Uint8Array(dataView.buffer)
        );
      }
    })
);

const stop = '';
