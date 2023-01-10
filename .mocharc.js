process.env.NODE_ENV = process.env.NODE_ENV || 'test';

module.exports = /** @type {import('mocha').MochaOptions} */ ({
  require: ['./spec/javascripts/support/mocha.js'],
  file: 'spec/javascripts/spec_helper.js',
  extension: ['js', 'jsx', 'ts', 'tsx'],
  'node-option': ['conditions=source'],
});
