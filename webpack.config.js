const { parse, resolve } = require('path');
const { sync: glob } = require('fast-glob');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

const mode = process.env.NODE_ENV || 'development';
const isProduction = mode === 'production';
const hashSuffix = isProduction ? '-[contenthash:8]' : '';
const devServerPort = process.env.WEBPACK_PORT;

const entries = glob('app/{components,javascript/packs}/*.{js,jsx}');

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode,
  devtool: 'eval-source-map',
  devServer: devServerPort && {
    static: {
      directory: './public',
      watch: false,
    },
    port: devServerPort,
    headers: { 'Access-Control-Allow-Origin': '*' },
    hot: false,
  },
  entry: entries.reduce((result, path) => {
    result[parse(path).name] = resolve(path);
    return result;
  }, {}),
  output: {
    filename: `[name]${hashSuffix}.js`,
    chunkFilename: `[name].chunk${hashSuffix}.js`,
    sourceMapFilename: `[name]${hashSuffix}.js.map`,
    path: resolve(__dirname, 'public/packs'),
    publicPath: devServerPort ? `http://localhost:${devServerPort}/packs/` : '/packs/',
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
      output: 'manifest.json',
    }),
    new RailsI18nWebpackPlugin(),
  ],
});
