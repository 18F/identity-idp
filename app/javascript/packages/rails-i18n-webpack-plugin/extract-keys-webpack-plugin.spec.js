const webpack = require('webpack');
const {
  getAdditionalAssetFilename,
  getTranslationKeys,
  isJavaScriptChunk,
} = require('./extract-keys-webpack-plugin.js');

const { Compiler, Module } = webpack;

describe('getAdditionalAssetFilename', () => {
  it('adds suffix to an existing file name', () => {
    const original = 'original.js';
    const suffix = 'en';
    const expected = 'original.en.js';

    expect(getAdditionalAssetFilename(original, suffix)).to.equal(expected);
  });
});

describe('getTranslationKeys', () => {
  const source = `
    import { t } from '@18f/identity-i18n';

    const text = t('explicit.call');

    // i18n-tasks-use t('comment.added.1')
    /* i18n-tasks-use t('comment.added.2') */
    /**
     * i18n-tasks-use t('comment.added.3')
     */
    Array.from({ length: 3 }, (_, i) => t(\`comment.added.\${i + 1}\`))
  `;

  it('returns keys', () => {
    expect(getTranslationKeys(source)).to.deep.equal([
      'explicit.call',
      'comment.added.1',
      'comment.added.2',
      'comment.added.3',
    ]);
  });
});

describe('isJavaScriptChunk', () => {
  context('non-js chunk', () => {
    const chunk = new Compiler('').createCompilation().addChunk('example.json');
    chunk.entryModule = new Module('json');

    it('returns false', () => {
      expect(isJavaScriptChunk(chunk)).to.be.false();
    });
  });

  context('js chunk', () => {
    const chunk = new Compiler('').createCompilation().addChunk('example.js');
    chunk.entryModule = new Module('javascript/auto');

    it('returns true', () => {
      expect(isJavaScriptChunk(chunk)).to.be.true();
    });
  });
});
