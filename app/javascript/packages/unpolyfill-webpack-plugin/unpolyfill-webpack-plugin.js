const { NormalModuleReplacementPlugin } = require('webpack');
const manifest = require('./package.json');

const polyfillModules = Object.keys(manifest.exports)
  .filter((exportKey) => exportKey !== '.')
  .map((exportKey) => exportKey.replace(/^\.\//, ''));

const polyfillPattern = new RegExp(`^${polyfillModules.join('|')}$`);

class UnpolyfillWebpackPlugin extends NormalModuleReplacementPlugin {
  constructor() {
    super(polyfillPattern, (result) => {
      result.request = `@18f/identity-unpolyfill-webpack-plugin/${result.request}`;
    });
  }
}

module.exports = UnpolyfillWebpackPlugin;
