const { parse, resolve } = require('path');
const { sync: glob } = require('fast-glob');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

const env = process.env.NODE_ENV || process.env.RAILS_ENV || 'development';
const isProductionEnv = env === 'production';
const isTestEnv = env === 'test';
const mode = isProductionEnv ? 'production' : 'development';
const hashSuffix = isProductionEnv ? '-[contenthash:8]' : '';
const devServerPort = process.env.WEBPACK_PORT;

const entries = glob('app/{components,javascript/packs}/*.{js,jsx}');

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode,
  devtool: isProductionEnv ? false : 'eval-source-map',
  target: ['web', 'es5'],
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
    filename: `js/[name]${hashSuffix}.js`,
    chunkFilename: `js/[name].chunk${hashSuffix}.js`,
    sourceMapFilename: `js/[name]${hashSuffix}.js.map`,
    path: resolve(__dirname, 'public/packs'),
    publicPath: devServerPort ? `http://localhost:${devServerPort}/packs/` : '/packs/',
  },
  resolve: {
    extensions: ['.js', '.jsx'],
  },
  module: {
    rules: [
      !isProductionEnv && {
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
    new RailsI18nWebpackPlugin({
      onMissingString(key, locale) {
        if (isTestEnv) {
          throw new Error(`Unexpected missing string for locale '${locale}': '${key}'`);
        }
      },
    }),
  ],
});
