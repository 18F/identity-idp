module.exports = /** @type {import('svgo').OptimizeOptions} */ ({
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          // `minifyStyles` is disabled since some SVG use `@keyframes` for animations (for example,
          // `id-card.svg`), which is removed with the `minifyStyles` plugin.
          // Related: https://github.com/svg/svgo/issues/888
          minifyStyles: false,

          // `removeViewBox` is disabled since `viewbox` is a meaningful attribute, and notably this
          // can cause rendering issues in some browsers.
          // Related: https://github.com/svg/svgo/issues/1128
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
