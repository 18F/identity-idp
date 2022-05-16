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
    const text = t('forms.button.submit');
    const message = t('forms.messages', { count: 2 });
    const values = t(['forms.key1', 'forms.key2']);

    // i18n-tasks-use t('item.1')
    /* i18n-tasks-use t('item.2') */
    /**
     * i18n-tasks-use t('item.3')
     */
    Array.from({ length: 3 }, (_, i) => t(\`item.$\{i + 1}\`));
    // Emulate Babel template literal transpilation
    // See: https://babeljs.io/repl#?browsers=ie%2011&code_lz=C4CgBglsCmC2B0ASA3hABAajQRgL5gEog
    Array.from({ length: 3 }, (_, i) => t('item.'.concat(i + 1)));
  `;

  it('returns keys', () => {
    expect(getTranslationKeys(source)).to.deep.equal([
      'forms.button.submit',
      'forms.messages',
      'forms.key1',
      'forms.key2',
      'item.1',
      'item.2',
      'item.3',
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
