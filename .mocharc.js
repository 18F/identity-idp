process.env.NODE_ENV = process.env.NODE_ENV || 'test';

module.exports = /** @type {import('mocha').MochaOptions} */ ({
  require: ['./spec/javascript/support/mocha.js'],
  file: 'spec/javascript/spec_helper.js',
  extension: ['js', 'jsx', 'ts', 'tsx'],
  loader: ['quibble'],
  conditions: ['source'],
});
