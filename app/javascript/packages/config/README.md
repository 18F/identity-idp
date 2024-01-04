# `@18f/identity-config`

Utilities for retrieving global application configuration values.

## Usage

From your JavaScript code, retrieve a configuration value using the `getConfigValue` export:

```ts
const appName = getConfigValue('appName');
```

The configuration is expected to be bootstrapped in page markup within a `<script type="application/json" data-config>` script tag.

```html
<script type="application/json" data-config>
  {
    "appName": "Login.gov"
  }
</script>
```
