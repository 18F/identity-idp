const externals = Object.keys(require('./package.json').dependencies);

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode: 'production',
  target: ['node'],
  entry: {
    'address-search': './components/address-search.tsx',
  },
  experiments: {
    outputModule: true,
  },
  output: {
    module: true,
    chunkFormat: 'commonjs',
    filename: '[name].js',
    library: {
      type: 'module',
    },
  },
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.mts', '.cts'],
  },
  externals,
  module: {
    rules: [
      {
        use: {
          loader: 'babel-loader',
        },
      },
    ],
  },
  optimization: {
    minimize: false,
  },
});
