module.exports = (api) => {
  const isTestEnv = api.env('test');

  return {
    presets: [
      ['@babel/preset-env', { targets: isTestEnv ? 'current node' : undefined }],
      '@babel/typescript',
      [
        '@babel/preset-react',
        {
          runtime: 'automatic',
        },
      ],
    ],
    plugins: [
      [
        'polyfill-corejs3',
        {
          method: 'usage-global',
          targets: isTestEnv ? 'current node' : '> 1% and supports es6-module',
        },
      ],
      [
        'polyfill-regenerator',
        {
          method: 'usage-global',
          targets: isTestEnv ? 'current node' : undefined,
        },
      ],
    ],
    sourceType: 'unambiguous',
  };
};
