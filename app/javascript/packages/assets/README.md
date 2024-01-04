# `@18f/identity-assets`

Utilities for resolving asset URLs from [Ruby on Rails' Asset Pipeline](https://guides.rubyonrails.org/asset_pipeline.html).

## Usage

Within your code, use `getAssetPath` and provide a raw asset path, where the expected return value is the URL resolved by the Ruby on Rails Asset pipeline:

```ts
const spriteURL = getAssetPath('sprite.svg');
```

The included Webpack plugin will scan for references to `getAssetPath` and add those as assets of the associated Webpack entrypoint.

```ts
// webpack.config.js

module.exports = {
  // ...
  plugins: [
    // ...
    new RailsAssetsWebpackPlugin(),
  ],
};
```

The expectation is that this can be used in combination with a tool like [`WebpackManifestPlugin`](https://github.com/shellscape/webpack-manifest-plugin) to generate a JSON manifest of all assets expected to be loaded with a given Webpack entrypoint, so that the backend can ensure those asset paths are populated into a `<script type="applicaton/json" data-asset-map>` tag containing a JSON mapping of original asset names to the resolved URL.

```html
<script type="application/json" data-asset-map>
  {
    "sprite.svg": "https://cdn.example.com/path/to/sprite.svg"
  }
</script>
```
