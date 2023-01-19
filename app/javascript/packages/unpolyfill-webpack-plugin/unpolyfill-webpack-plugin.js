const { NormalModuleReplacementPlugin } = require('webpack');
const manifest = require('./package.json');

const polyfills = new RegExp(
  `^${Object.keys(manifest.exports)
    .filter((exportKey) => exportKey !== '.')
    .map((exportKey) => exportKey.replace(/^\.\//, ''))
    .join('|')}$`,
);

class UnpolyfillWebpackPlugin extends NormalModuleReplacementPlugin {
  constructor() {
    super(polyfills, (result) => {
      result.request = `@18f/identity-unpolyfill-webpack-plugin/${result.request}`;
    });
  }
}

module.exports = UnpolyfillWebpackPlugin;
