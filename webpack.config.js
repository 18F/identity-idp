const { parse, resolve } = require('path');
const url = require('url');
const { sync: glob } = require('fast-glob');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');
const RailsAssetsWebpackPlugin = require('@18f/identity-assets/webpack-plugin');

const env = process.env.NODE_ENV || process.env.RAILS_ENV || 'development';
const host = process.env.HOST || 'localhost';
const isLocalhost = host === 'localhost';
const isProductionEnv = env === 'production';
const isTestEnv = env === 'test';
const mode = isProductionEnv ? 'production' : 'development';
const hashSuffix = isProductionEnv ? '-[chunkhash:8]' : '';
const devServerPort = process.env.WEBPACK_PORT;
const devtool = process.env.WEBPACK_DEVTOOL || (isProductionEnv ? 'source-map' : 'eval-source-map');

const entries = glob('app/{components,javascript/packs}/*.{ts,tsx,js,jsx}');

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode,
  devtool,
  target: ['web'],
  devServer: {
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
    publicPath:
      devServerPort && isLocalhost ? `http://localhost:${devServerPort}/packs/` : '/packs/',
  },
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.mts', '.cts'],
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
        test: /\.[cm]?[jt]sx?$/,
        exclude: /node_modules\/(?!@18f\/identity-)/,
        use: {
          loader: 'babel-loader',
        },
      },
    ].filter(Boolean),
  },
  optimization: {
    chunkIds: 'natural',
  },
  plugins: [
    new WebpackAssetsManifest({
      entrypoints: true,
      publicPath(filename, plugin) {
        // Only prepend public path for JavaScript files, since all other assets will be processed
        // using Rails asset pipeline, and should use the original filename.
        return filename.endsWith('.js')
          ? url.resolve(plugin.compiler.options.output.publicPath, filename)
          : filename;
      },
      writeToDisk: true,
      integrity: isProductionEnv,
      output: 'manifest.json',
      transform(manifest) {
        const srcIntegrity = {};
        for (const [key, { src, integrity }] of Object.entries(manifest)) {
          if (integrity) {
            srcIntegrity[src] = integrity;
            delete manifest[key];
          }
        }

        manifest.integrity = srcIntegrity;
        return manifest;
      },
    }),
    new RailsI18nWebpackPlugin({
      onMissingString(key, locale) {
        if (isTestEnv) {
          throw new Error(`Unexpected missing string for locale '${locale}': '${key}'`);
        }
      },
    }),
    new RailsAssetsWebpackPlugin(),
  ],
});
