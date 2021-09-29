import { I18n, replaceVariables } from './index.js';

describe('replaceVariables', () => {
  it('replaces all variables', () => {
    const result = replaceVariables('The price is $%{price}, not %{price} €', { price: '2' });

    expect(result).to.equal('The price is $2, not 2 €');
  });
});

describe('I18n', () => {
  const { t } = new I18n({ strings: { known: 'translation' } });

  describe('#t', () => {
    it('returns localized key value', () => {
      expect(t('known')).to.equal('translation');
    });

    it('falls back to key value', () => {
      expect(t('unknown')).to.equal('unknown');
    });
  });
});
