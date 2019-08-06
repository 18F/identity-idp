const path = require('path')
const CopyPlugin = require('copy-webpack-plugin');

module.exports = {
  plugins: [
    new CopyPlugin([
      {
        from: 'vendor/assets/javascripts/es5-shim.min.js',
        to: path.join(__dirname, '../../public/packs'),
        force: true,
      },
      {
        from: 'vendor/assets/javascripts/html5shiv.js',
        to: path.join(__dirname, '../../public/packs'),
        force: true,
      },
      {
        from: 'vendor/assets/javascripts/respond.min.js',
        to: path.join(__dirname, '../../public/packs'),
        force: true,
      },
      {
        from: 'vendor/assets/javascripts/local-time.js',
        to: path.join(__dirname, '../../public/packs'),
        force: true,
      },
    ]),
  ],

  resolve: {
    modules: [
      path.join(__dirname, '../public/packs'),
      'node_modules',
    ]
  },
}