// Compile Basscss source to scss syntax

var fs = require('fs');
var path = require('path');
var cssscss = require('css-scss');
var cssnext = require('cssnext');
var basscss = require('basscss');

var modules = basscss.variables;
modules = modules.concat(basscss.modules);
modules = modules.concat(basscss.optional_modules);

var cssnextOpts = {
  features: {
    customProperties: false,
    customMedia: false,
    calc: false,
    colorFunction: false,
    rem: false,
  }
};

// Build partials
modules.forEach(function(m) {

  var css = '@import "' + m + '";';
  var imported = cssnext(css, cssnextOpts);
  var scss = cssscss(imported);
  var filename = '_' + m.replace('basscss-', '') + '.scss';

  fs.writeFileSync(filename, scss);

});

// Build index
var index = modules.map(function(m) {
  return '@import "' + m.replace(/^basscss\-/,'') + '";';
});

fs.writeFileSync('basscss.scss', index.join('\n'));

