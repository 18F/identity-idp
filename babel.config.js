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
          targets,
        },
      ],
      ['polyfill-regenerator', { method: 'usage-global', targets }],
    ],
    sourceType: 'unambiguous',
  };
};
