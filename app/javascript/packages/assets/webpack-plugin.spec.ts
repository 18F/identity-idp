const path = require('path');
const { promises: fs } = require('fs');
const webpack = require('webpack');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const AssetsWebpackPlugin = require('./webpack-plugin');

describe('AssetsWebpackPlugin', () => {
  it('generates expected output', (done) => {
    webpack(
      {
        mode: 'development',
        devtool: false,
        entry: path.resolve(__dirname, 'spec/fixtures/in.js'),
        plugins: [
          new AssetsWebpackPlugin(),
          new WebpackAssetsManifest({
            entrypoints: true,
            publicPath: true,
            writeToDisk: true,
            output: 'actualmanifest.json',
          }),
        ],
        output: {
          path: path.resolve(__dirname, 'spec/fixtures'),
          filename: 'actual[name].js',
        },
      },
      async (webpackError) => {
        try {
          expect(webpackError).to.be.null();

          const manifest = JSON.parse(
            await fs.readFile(
              path.resolve(__dirname, 'spec/fixtures/actualmanifest.json'),
              'utf-8',
            ),
          );

          expect(manifest.entrypoints.main.assets.svg).to.include.all.members(['foo.svg']);

          done();
        } catch (error) {
          done(error);
        }
      },
    );
  });
});
