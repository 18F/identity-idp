const sinon = require('sinon');
const path = require('path');
const { promises: fs } = require('fs');
const webpack = require('webpack');
const WebpackAssetsManifest = require('webpack-assets-manifest');
const RailsI18nWebpackPlugin = require('./rails-i18n-webpack-plugin.js');

const { compact } = RailsI18nWebpackPlugin;

describe('RailsI18nWebpackPlugin', () => {
  it('generates expected output', (done) => {
    const onMissingString = sinon.spy();

    webpack(
      {
        mode: 'development',
        devtool: false,
        entry: {
          1: path.resolve(__dirname, 'spec/fixtures/in1.js'),
          2: path.resolve(__dirname, 'spec/fixtures/in2.js'),
        },
        plugins: [
          new RailsI18nWebpackPlugin({
            configPath: path.resolve(__dirname, 'spec/fixtures/locales'),
            onMissingString,
          }),
          new WebpackAssetsManifest({
            entrypoints: true,
            publicPath: true,
            writeToDisk: true,
            output: 'actualmanifest.json',
          }),
        ],
        externals: {
          '@18f/identity-i18n': '_i18n_',
        },
        resolve: {
          extensions: ['.js', '.foo'],
        },
        output: {
          path: path.resolve(__dirname, 'spec/fixtures'),
          filename: 'actual[name].js',
        },
        optimization: {
          chunkIds: 'named',
          splitChunks: {
            chunks: 'all',
            minSize: 0,
          },
        },
      },
      async (webpackError) => {
        try {
          expect(webpackError).to.be.null();

          const fixtures = await fs.readdir(path.resolve(__dirname, 'spec/fixtures'));
          const expectedFiles = fixtures.filter((file) => file.startsWith('expected'));

          for (const expectedFile of expectedFiles) {
            const suffix = expectedFile.slice('expected'.length);
            const actualFile = `actual${suffix}`;
            // eslint-disable-next-line no-await-in-loop
            const [expected, actual] = await Promise.all(
              [expectedFile, actualFile].map((file) =>
                fs.readFile(path.resolve(__dirname, 'spec/fixtures', file), 'utf-8'),
              ),
            );

            expect(expected).to.equal(actual);
          }

          expect(onMissingString).to.have.callCount(7);
          expect(onMissingString).to.have.been.calledWithExactly('item.1', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('item.2', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('forms.button.submit', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.2', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'en');

          const manifest = JSON.parse(
            await fs.readFile(path.resolve(__dirname, 'spec/fixtures/actualmanifest.json'), 'utf-8'),
          );

          // 3 outputs + 3 x 3 languages - 1 dynamic output
          expect(manifest.entrypoints['1'].assets.js).to.have.lengthOf(11);

          // 3 outputs + 2 x 3 languages (no locale strings for base output) - 1 dynamic output
          expect(manifest.entrypoints['2'].assets.js).to.have.lengthOf(8);

          done();
        } catch (error) {
          done(error);
        }
      },
    );
  });

  context('in production mode', () => {
    it('adds hash suffix to javascript locale assets', (done) => {
      webpack(
        {
          mode: 'production',
          devtool: false,
          entry: path.resolve(__dirname, 'spec/fixtures/production/in.js'),
          plugins: [
            new RailsI18nWebpackPlugin({
              configPath: path.resolve(__dirname, 'spec/fixtures/locales'),
            }),
            new WebpackAssetsManifest({
              entrypoints: true,
              publicPath: true,
              writeToDisk: true,
              output: 'actualmanifest.json',
            }),
          ],
          externals: {
            '@18f/identity-i18n': '_i18n_',
          },
          output: {
            path: path.resolve(__dirname, 'spec/fixtures/production'),
            filename: 'actual[name].js',
          },
        },
        async (webpackError) => {
          try {
            expect(webpackError).to.be.null();
            const manifest = JSON.parse(
              await fs.readFile(path.resolve(__dirname, 'spec/fixtures/production/actualmanifest.json'), 'utf-8'),
            );

            expect(manifest).to.deep.equal({
              'actualmain-5b00aabc.en.js': 'actualmain-5b00aabc.en.js',
              'actualmain-941d1f5f.es.js': 'actualmain-941d1f5f.es.js',
              'actualmain.js': 'actualmain.js',
              entrypoints: {
                main: {
                  assets: {
                    js: [
                      'actualmain.js',
                      'actualmain-5b00aabc.en.js',
                      'actualmain-941d1f5f.es.js',
                      'actualmain-5b00aabc.fr.js',
                    ],
                  },
                },
              },
              'main.js': 'actualmain-5b00aabc.fr.js',
            });
            done();
          } catch (error) {
            done(error);
          }
        },
      );
    });
  });
});

describe('compact', () => {
  it('returns truthy values', () => {
    const values = [1, 0, null, false];
    const result = compact(values);

    expect(result).to.deep.equal([1]);
  });
});
