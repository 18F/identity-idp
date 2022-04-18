const path = require('path');
const { promises: fs } = require('fs');
const webpack = require('webpack');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const AssetsWebpackPlugin = require('./webpack-plugin');

const { getAssetPaths } = AssetsWebpackPlugin;

describe('AssetsWebpackPlugin', () => {
  ['development', 'production'].forEach((mode) => {
    context(mode, () => {
      it('generates expected output', (done) => {
        webpack(
          {
            mode,
            devtool: false,
            entry: path.resolve(__dirname, 'spec/fixtures/in.js'),
            plugins: [
              new AssetsWebpackPlugin(),
              new WebpackAssetsManifest({
                entrypoints: true,
                publicPath: true,
                writeToDisk: true,
                output: `actual${mode}manifest.json`,
              }),
            ],
            output: {
              path: path.resolve(__dirname, 'spec/fixtures'),
              filename: `actual${mode}[name].js`,
            },
            optimization: {
              concatenateModules: false,
            },
          },
          async (webpackError) => {
            try {
              expect(webpackError).to.be.null();

              const manifest = JSON.parse(
                await fs.readFile(
                  path.resolve(__dirname, `spec/fixtures/actual${mode}manifest.json`),
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
  });

  describe('.getAssetPaths()', () => {
    context('webpack unbound call', () => {
      const source = "(0,_assets__WEBPACK_IMPORTED_MODULE_0__.getAssetPath)('foo.svg')";

      it('returns asset paths', () => {
        expect(getAssetPaths(source)).to.have.all.members(['foo.svg']);
      });
    });

    context('mangled export name', () => {
      const source = "(0,_assets__WEBPACK_IMPORTED_MODULE_0__/* .getAssetPath */ .K)('foo.svg');";

      it('returns asset paths', () => {
        expect(getAssetPaths(source)).to.have.all.members(['foo.svg']);
      });
    });

    context('mangled export name, multiple letters', () => {
      const source = "(0,_assets__WEBPACK_IMPORTED_MODULE_0__/* .getAssetPath */ .Aa)('foo.svg');";

      it('returns asset paths', () => {
        expect(getAssetPaths(source)).to.have.all.members(['foo.svg']);
      });
    });

    context('manged export name, no whitespace', () => {
      const source = "(0,assets/* getAssetPath */.K)('foo.svg'),";

      it('returns asset paths', () => {
        expect(getAssetPaths(source)).to.have.all.members(['foo.svg']);
      });
    });
  });
});
