const { environment } = require('@rails/webpacker');

const babelLoader = environment.loaders.get('babel');
babelLoader.include.push(/node_modules\/@18f\/identity-/);
babelLoader.exclude = /node_modules\/(?!@18f\/identity-)/;

module.exports = environment;
