const { parse, resolve } = require('path');
const { sync: glob } = require('fast-glob');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

const mode = process.env.NODE_ENV || 'development';
const isProduction = mode === 'production';
const hashSuffix = isProduction ? '-[contenthash:8].digested' : '';
const isDevServer = !!process.env.WEBPACK_SERVE;

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode,
  devtool: 'eval-source-map',
  devServer: {
    static: {
      directory: './public',
      watch: false,
    },
    port: 3035,
    headers: { 'Access-Control-Allow-Origin': '*' },
    hot: false,
  },
  entry: glob('app/{components,javascript/packs}/*.{js,jsx}').reduce((result, path) => {
    result[parse(path).name] = resolve(path);
    return result;
  }, {}),
  output: {
    filename: `[name]${hashSuffix}.js`,
    chunkFilename: `[name].chunk${hashSuffix}.js`,
    sourceMapFilename: `[name]${hashSuffix}.js.map`,
    path: resolve(__dirname, 'public/packs'),
    publicPath: isDevServer ? 'http://localhost:3035/packs/' : '/packs/',
  },
  resolve: {
    extensions: ['.js', '.jsx'],
  },
  module: {
    rules: [
      !isProduction && {
        test: /\.js$/,
        include: /node_modules/,
        enforce: 'pre',
        use: ['source-map-loader'],
      },
      {
        test: /\.jsx?$/,
        exclude: /node_modules\/(?!@18f\/identity-|identity-style-guide|uswds|receptor|elem-dataset)/,
        use: {
          loader: 'babel-loader',
        },
      },
    ].filter(Boolean),
  },
  optimization: {
    chunkIds: 'natural',
    splitChunks: { chunks: 'all' },
  },
  plugins: [
    new WebpackAssetsManifest({
      entrypoints: true,
      publicPath: true,
      writeToDisk: true,
    }),
    new RailsI18nWebpackPlugin(),
  ],
});
