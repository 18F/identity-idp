# `@18f/identity-lite-webpack-dev-server`

Minimal, zero-dependency alternative to Webpack's default development web server.

**What does it do the same as `webpack-dev-server`?**

- Serves static assets from the built output directory
- Pauses page loads during compilation to guarantee that a page loads with the latest JavaScript

**What doesn't it do that `webpack-dev-server` does?**

Most everything else! Notably, it does not:

- Automatically reload the page when compilation finishes
- Handle anything other than JavaScript

## Usage

If migrating from `webpack-dev-server`:

- Remove your `devServer` configuration from `webpack.config.js`

Add an instance of `LiteWebpackDevServerPlugin` to your Webpack `plugins` array. The example below
shows how you might conditionally include the plugin in local development only, to avoid the server
being run in production environments.

```ts
// webpack.config.js

const { DEV_SERVER_PORT } = process.env;

export default {
  // ...
  plugins: [
    // ...
    DEV_SERVER_PORT &&
      new LiteWebpackDevServerPlugin({ publicPath: './public', port: Number(DEV_SERVER_PORT) }),
  ]
};
```

Supported options:

- `publicPath` (`string`): Relative path to the root of the static file server
- `port` (`number`): Port on which the static file server should listen
- `headers` (`object`): Additional headers to include in every response
