
var fs = require('fs');
var path = require('path');
var assert = require('assert');
var sass = require('node-sass');

var filenames = fs.readdirSync(path.join(__dirname, '..'))
  .filter(function(name) {
    return name.match(/\.scss$/);
  })
  .filter(function(name) {
    return (name !== '_defaults.scss' && name !== 'basscss.scss');
  });

var files = filenames.map(function(filename) {
  var src = fs.readFileSync(path.join(__dirname, '../' + filename), 'utf8');
  return { src: src, name: filename };
});

var defaults = fs.readFileSync(path.join(__dirname, '../_defaults.scss'), 'utf8');

var index = {
  name: 'index',
  src: fs.readFileSync(path.join(__dirname, '../basscss.scss'), 'utf8')
};


describe('basscss-sass', function() {

  function renderSass(file) {
    it('should compile scss for ' + file.name, function() {
      var src = defaults + '\n' + file.src;
      assert.doesNotThrow(function() {
        sass.renderSync({ data: src });
      });
    });
  }

  files.forEach(renderSass);
  renderSass(index);

});

