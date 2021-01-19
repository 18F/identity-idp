const environment = require('./environment')
const { merge } = require('webpack-merge')

const sassLoader = environment.loaders.get('sass');

sassLoader.use.map((loader) => {
  if (loader.loader === "css-loader") {
    loader.options.sourceMap = false;
  }
});

module.exports = environment.toWebpackConfig()
