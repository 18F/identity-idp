const { parse, resolve } = require('path');
const { webpackConfig, rules } = require('@rails/webpacker');
const { sync: glob } = require('fast-glob');
const RailsI18nWebpackPlugin = require('@18f/identity-rails-i18n-webpack-plugin');

glob('app/components/*.js').forEach((path) => {
  webpackConfig.entry[parse(path).name] = resolve(path);
});

const findLoader = (pkg) =>
  rules
    .flatMap((rule) => rule.use)
    .filter(Boolean)
    .find(({ loader }) => loader === require.resolve(pkg));

// Prepend minimum required design system variables, mixins, and functions to make available to all
// Webpack-imported SCSS files. Notably, this should _not_ include any actual CSS output on its own.
findLoader('sass-loader').options.additionalData = `
$font-path: 'node_modules/identity-style-guide/dist/assets/fonts';
$image-path: 'node_modules/identity-style-guide/dist/assets/img';
@import 'node_modules/identity-style-guide/dist/assets/scss/packages/required';`;

findLoader('css-loader').options.sourceMap = false;

rules.push({
  test: /\.js$/,
  include: /node_modules/,
  enforce: 'pre',
  use: ['source-map-loader'],
});

webpackConfig.plugins.push(new RailsI18nWebpackPlugin());

module.exports = webpackConfig;
