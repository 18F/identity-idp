# Rails i18n Webpack Plugin

## Usage

[Use as any other Webpack plugin](https://webpack.js.org/concepts/#plugins) or, if you're using Webpacker, append the plugin in your environment configuration:

```js
// config/webpack/[env].js
const { environment } = require('@rails/webpacker');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

environment.plugins.append('RailsI18nWebpackPlugin', new RailsI18nWebpackPlugin());
```

## Configuration

### `template`

A [Node.js `util.format`](https://nodejs.org/api/util.html#util_util_format_format_args)-formatted string, given an object of strings for each processed chunk.

Optional, defaults to `'(window._locale_data = window._locale_data || []).push(%j);'`.

### `configPath`

The directory where locale YAML data is located. Defaults to `config/locales` relative to the project root.

Optional, defaults to `path.resolve(process.cwd(), 'config/locales')`.

### `defaultLocale`

The default locale for the application.

Optional, defaults to `'en'`.

### `onMissingString`

Callback invoked when a key cannot be found in locale data, optionally returning a string to return in its place.

Optional, defaults to `() => {}`.
