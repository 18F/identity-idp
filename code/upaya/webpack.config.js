var webpack = require('webpack');

module.exports = {
  entry: './public/js/entry.js',

  output: {
    filename: 'bundle.js',
    path: __dirname + '/public/build'
  },

  devtool: '#cheap-module-eval-source-map',

  module: {
    loaders: [
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        loader: 'babel-loader',
        query: {
          presets: ['es2015', 'stage-0', 'react'],
        }
      },
    ]
  },

  resolve: {
    extensions: ['', '.js', '.jsx']
  }
};