const clean = require('postcss-clean');

module.exports = {
  plugins: [
    clean({
      format: process.env.NODE_ENV === 'production' ? undefined : 'beautify',
    }),
  ],
};
