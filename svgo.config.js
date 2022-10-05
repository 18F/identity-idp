module.exports = /** @type {import('svgo').OptimizeOptions} */ ({
  multipass: true,
  minifyStyles: false,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          removeViewBox: false,
        },
      },
    },
    {
      name: 'removeAttrs',
      params: {
        attrs: 'data-name',
      },
    },
  ],
});
