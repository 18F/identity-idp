const { environment } = require('@rails/webpacker');

environment.loaders.delete('file');
environment.loaders.delete('nodeModules');
environment.loaders.delete('moduleSass');
environment.loaders.delete('moduleCss');
environment.loaders.delete('css');

const babelLoader = environment.loaders.get('babel');
babelLoader.include.push(/node_modules\/@18f\/identity-/);
babelLoader.exclude = /node_modules\/(?!@18f\/identity-)/;

const sassLoader = environment.loaders.get('sass');

const sourceMapLoader = {
  test: /\.js$/,
  include: /node_modules/,
  enforce: 'pre',
  use: ['source-map-loader'],
};
environment.loaders.append('sourceMap', sourceMapLoader);

module.exports = environment;
