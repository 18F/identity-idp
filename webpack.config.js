const { parse, resolve } = require('path');
const { sync: glob } = require('fast-glob');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

const mode = process.env.NODE_ENV || 'development';
const isProduction = mode === 'production';
const hashSuffix = isProduction ? '-[contenthash:8].digested' : '';

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode,
  devtool: 'cheap-source-map',
  entry: glob('app/{components,javascript/packs}/*.{js,jsx}').reduce((result, path) => {
    result[parse(path).name] = resolve(path);
    return result;
  }, {}),
  output: {
    filename: `[name]${hashSuffix}.js`,
    chunkFilename: `[name].chunk${hashSuffix}.js`,
    sourceMapFilename: `[name]${hashSuffix}.js.map`,
    path: resolve(__dirname, 'public/packs'),
    publicPath: '/packs/',
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
    }),
    new RailsI18nWebpackPlugin(),
  ],
});
