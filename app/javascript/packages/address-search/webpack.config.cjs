module.exports = /** @type {import('webpack').Configuration} */ ({
  mode: 'production',
  target: ['node'],
  entry: {
    index: './',
  },
  experiments: {
    outputModule: true,
  },
  output: {
    module: true,
    chunkFormat: false,
    filename: '[name].js',
    library: {
      type: 'module',
    },
  },
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.mts', '.cts'],
  },
  externals: /^(?!(@18f\/identity-|\.))/,
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
