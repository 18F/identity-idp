const {
  getAdditionalAssetFilename,
  getTranslationKeys,
  isJavaScriptFile,
} = require('./extract-keys-webpack-plugin.js');

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

describe('isJavaScriptFile', () => {
  context('non-js filename', () => {
    const filename = 'example.json';

    it('returns false', () => {
      expect(isJavaScriptFile(filename)).to.be.false();
    });
  });

  context('js filename', () => {
    const filename = 'example.js';

    it('returns true', () => {
      expect(isJavaScriptFile(filename)).to.be.true();
    });
  });
});
