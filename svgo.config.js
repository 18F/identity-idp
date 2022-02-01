module.exports = {
  multipass: true,
  minifyStyles: false,
  removeViewBox: false,
  plugins: [
    {
      name: 'removeAttrs',
      params: {
        attrs: 'data-name',
      },
    },
  ],
};
