const environment = require('./environment')
const { merge } = require('webpack-merge')

const sassLoader = environment.loaders.get('sass');

sassLoader.use.map(function(loader) {
  if (loader.loader === "css-loader") {
    loader.options = merge(loader.options, { sourceMap: false });
  }
});

module.exports = environment.toWebpackConfig()
