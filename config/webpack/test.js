const environment = require('./environment');

environment.plugins.get('RailsI18nWebpackPlugin').options.onMissingString = (key, locale) => {
  throw new Error(`Unexpected missing string for locale '${locale}': '${key}'`);
};

module.exports = environment.toWebpackConfig();
