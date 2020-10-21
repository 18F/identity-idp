const environment = require('./environment');

environment.config.devtool = 'eval-source-map';

module.exports = environment.toWebpackConfig();
