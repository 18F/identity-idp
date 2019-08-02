const path = require('path');
const EventHooksPlugin = require('event-hooks-webpack-plugin');
const fs = require('fs-extra')



module.exports = {
  plugins: [
    new EventHooksPlugin({
      'before-run': (compilation, done) => {
        fs.copy('node_modules/identity-style-guide/dist/assets', path.join(__dirname, '../../app/javascript/identity-style-guide'), done);
      }
    }),
  ],
  resolve: {
    modules: [
      path.join(__dirname, '../../public/packs'),
      'node_modules'
    ]
  },
};