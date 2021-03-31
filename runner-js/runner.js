#!/usr/bin/env node

var readline = require('readline');
var rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

var type = 'code';
var code = '';
var runner = null;

rl.on('line', function(line){
    if (type === 'code') {
        if (line.startsWith('__END__CODE__')) {
            type = 'run';
            console.log("READY");
        } else {
            code += line;
            code += "\n";
        }
    } else if (type === 'run') {
        if (line.startsWith('EXIT')) {
            process.exit(0);
        }
        try {
            if (!runner) {
                runner = new Function('data',code);
            }
            var run_data = {};
            try {
                 run_data = JSON.parse(line);
            } catch(err) {
            }
            result = runner(run_data);
            if (Array.isArray(result)) {
                console.log(JSON.stringify(result));
            } else {
                console.log('[]');
            }
        } catch(err) {
            console.log(JSON.stringify(['error',err.message,[err.stack]]));
            process.exit(0);
        }
    }
});
