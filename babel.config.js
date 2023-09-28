module.exports = (api) => {
  const isTestEnv = api.env('test');

  let targets;
  if (isTestEnv) {
    targets = 'current node';
  }

  return {
    presets: [
      ['@babel/preset-env', { targets }],
      ['@babel/typescript', { optimizeConstEnums: true }],
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
          targets,
        },
      ],
      ['polyfill-regenerator', { method: 'usage-global', targets }],
    ],
    sourceType: 'unambiguous',
  };
};
