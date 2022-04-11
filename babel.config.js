module.exports = (api) => {
  const isTestEnv = api.env('test');

  let targets;
  if (isTestEnv) {
    targets = 'current node';
  }

  return {
    presets: [
      ['@babel/preset-env', { targets }],
      '@babel/typescript',
      [
        '@babel/preset-react',
        {
          runtime: 'automatic',
        },
      ],
    ],
    plugins: [
      ['@babel/plugin-proposal-decorators', { version: 'legacy' }],
      [
        'polyfill-corejs3',
        {
          method: 'usage-global',
          targets: targets ?? '> 1% and supports es6-module',
        },
      ],
      ['polyfill-regenerator', { method: 'usage-global', targets }],
    ],
    sourceType: 'unambiguous',
  };
};
