process.env.NODE_ENV = process.env.NODE_ENV || 'test';

module.exports = {
  require: ['./spec/javascripts/support/babel.js'],
  file: 'spec/javascripts/spec_helper.js',
  extension: ['js', 'jsx'],
};
