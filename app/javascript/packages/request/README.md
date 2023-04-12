# `@18f/identity-request`

Wraps the native fetch API to include IDP-specific configuration.

```js
request('http://api.com', { method: post, json: { some: 'POJO' }, csrf: true }) // includes the IDP CSRF and stringifies JSON.
```
