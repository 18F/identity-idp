const externals = Object.keys(require('./package.json').dependencies);

module.exports = /** @type {import('webpack').Configuration} */ ({
  mode: 'production',
  target: ['node'],
  entry: {
    'address-search': './components/address-search.tsx',
  },
  output: {
    filename: '[name].js',
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
