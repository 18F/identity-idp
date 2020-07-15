process.env.NODE_ENV = process.env.NODE_ENV || 'test';

module.exports = {
  require: ['@babel/register', 'spec/javascripts/spec_helper.js'],
  extension: ['js', 'jsx'],
};
