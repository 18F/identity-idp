# `@18f/identity-unpolyfill-webpack-plugin`

Webpack plugin to provide replacement modules for polyfill packages for polyfills which are no longer necessary, to optimize the size of the bundled output.

## Usage

Add an instance of the default export as a plugin of your `webpack.config.js`:

```js
import UnpolyfillWebpackPlugin from '@18f/identity-unpolyfill-webpack-plugin';

export default {
  // ...
  plugins: [
    new UnpolyfillWebpackPlugin(),
  ],
};
```
