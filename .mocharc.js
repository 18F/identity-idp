process.env.NODE_ENV = process.env.NODE_ENV || 'test';

module.exports = {
  require: ['./spec/javascript/support/mocha.js'],
  file: 'spec/javascript/spec_helper.js',
  extension: ['js', 'jsx', 'ts', 'tsx'],
};
