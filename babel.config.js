module.exports = function (api) {
  const validEnv = ['development', 'test', 'production'];
  const currentEnv = api.env();
  const isDevelopmentEnv = api.env('development');
  const isProductionEnv = api.env('production');
  const isTestEnv = api.env('test');

  if (!validEnv.includes(currentEnv)) {
    throw new Error(
      `${
        'Please specify a valid `NODE_ENV` or ' +
        '`BABEL_ENV` environment variables. Valid values are "development", ' +
        '"test", and "production". Instead, received: '
      }${JSON.stringify(currentEnv)}.`,
    );
  }

  return {
    presets: [
      '@babel/typescript',
      [
        '@babel/preset-react',
        {
          runtime: 'automatic',
        },
      ],
      isTestEnv && [
        '@babel/preset-env',
        {
          targets: {
            node: 'current',
          },
        },
      ],
      (isProductionEnv || isDevelopmentEnv) && [
        '@babel/preset-env',
        {
          forceAllTransforms: true,
          useBuiltIns: 'usage',
          corejs: 3,
          modules: false,
          // Exclude polyfills for features known to be provided by @18f/identity-polyfill package.
          // See: https://github.com/babel/babel-polyfills/blob/main/packages/babel-plugin-polyfill-corejs3/src/built-in-definitions.js
          exclude: ['web.url', 'web.url-search-params', 'es.promise'],
        },
      ],
    ].filter(Boolean),
    // For third-party dependencies compiled using Babel, don't assume module source type. Use
    // "unambiguous" for best-effort attempt to identify source type by patterns.
    overrides: [
      {
        test: /node_modules\/(?!@18f\/identity-)/,
        sourceType: 'unambiguous',
      },
    ],
  };
};
