const sinon = require('sinon');
const path = require('path');
const { promises: fs } = require('fs');
const webpack = require('webpack');
const RailsI18nWebpackPlugin = require('./rails-i18n-webpack-plugin.js');

const {
  dig,
  fromPairs,
  uniq,
  compact,
  getKeyPath,
  getKeyDomain,
  getKeyDomains,
} = RailsI18nWebpackPlugin;

describe('RailsI18nWebpackPlugin', () => {
  it('generates expected output', (done) => {
    const onMissingString = sinon.spy();

    webpack(
      {
        entry: {
          1: path.resolve(__dirname, 'spec/fixtures/in1.js'),
          2: path.resolve(__dirname, 'spec/fixtures/in2.js'),
        },
        plugins: [
          new RailsI18nWebpackPlugin({
            configPath: path.resolve(__dirname, 'spec/fixtures/locales'),
            onMissingString,
          }),
        ],
        output: {
          path: path.resolve(__dirname, 'spec/fixtures'),
          filename: 'actual[name].js',
        },
        optimization: {
          chunkIds: 'deterministic',
          splitChunks: {
            chunks: 'all',
            minSize: 0,
          },
        },
      },
      async () => {
        try {
          for (const chunkSuffix of ['1', '946']) {
            // eslint-disable-next-line no-await-in-loop
            const [script, en, es, fr] = await Promise.all([
              fs.readFile(path.resolve(__dirname, `spec/fixtures/actual${chunkSuffix}.js`)),
              ...['.en.js', '.es.js', '.fr.js'].map(async (localeSuffix) => [
                await fs.readFile(
                  path.resolve(__dirname, `spec/fixtures/expected${chunkSuffix}${localeSuffix}`),
                  'utf-8',
                ),
                await fs.readFile(
                  path.resolve(__dirname, `spec/fixtures/actual${chunkSuffix}${localeSuffix}`),
                  'utf-8',
                ),
              ]),
            ]);

            expect(script).to.not.be.empty();
            for (const [expected, actual] of [en, es, fr]) {
              expect(expected).to.equal(actual);
            }
          }

          expect(onMissingString).to.have.callCount(7);
          expect(onMissingString).to.have.been.calledWithExactly('item.1', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('item.2', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'es');
          expect(onMissingString).to.have.been.calledWithExactly('forms.button.submit', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.2', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'fr');
          expect(onMissingString).to.have.been.calledWithExactly('item.3', 'en');

          done();
        } catch (error) {
          done(error);
        }
      },
    );
  });
});

describe('dig', () => {
  it('returns undefined when called on a nullish object', () => {
    const object = undefined;
    const result = dig(object, ['a', 'b']);

    expect(result).to.be.undefined();
  });

  it('returns undefined when path is unreachable', () => {
    const object = {};
    const result = dig(object, ['a', 'b']);

    expect(result).to.be.undefined();
  });

  it('returns value at path', () => {
    const object = { a: { b: 1 } };
    const result = dig(object, ['a', 'b']);

    expect(result).to.be.equal(1);
  });
});

describe('fromPairs', () => {
  it('returns pairs of key value in object form', () => {
    const pairs = [
      ['a', 1],
      ['b', 2],
    ];
    const result = fromPairs(pairs);

    expect(result).to.deep.equal({ a: 1, b: 2 });
  });
});

describe('uniq', () => {
  it('returns unique values', () => {
    const values = [1, 2, 2, 3];
    const result = uniq(values);

    expect(result).to.deep.equal([1, 2, 3]);
  });
});

describe('compact', () => {
  it('returns truthy values', () => {
    const values = [1, 0, null, false];
    const result = compact(values);

    expect(result).to.deep.equal([1]);
  });
});

describe('getKeyPath', () => {
  it('returns key path parts', () => {
    const key = 'a.b.c';
    const result = getKeyPath(key);

    expect(result).to.deep.equal(['a', 'b', 'c']);
  });
});

describe('getKeyDomain', () => {
  context('key', () => {
    const key = 'a.b.c';

    it('returns domain', () => {
      const result = getKeyDomain(key);

      expect(result).to.equal('a');
    });
  });

  context('key path', () => {
    const keyPath = ['a', 'b', 'c'];

    it('returns domain', () => {
      const result = getKeyDomain(keyPath);

      expect(result).to.equal('a');
    });
  });
});

describe('getKeyDomains', () => {
  it('returns unique set of domains for keys', () => {
    const keys = ['a.b.c', 'a.d.e', 'b.f.g'];
    const domains = getKeyDomains(keys);

    expect(domains).to.deep.equal(['a', 'b']);
  });
});
