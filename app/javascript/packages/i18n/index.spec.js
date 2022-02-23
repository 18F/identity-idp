import { I18n, replaceVariables } from './index';

describe('replaceVariables', () => {
  it('replaces all variables', () => {
    const result = replaceVariables('The price is $%{price}, not %{price} €', { price: '2' });

    expect(result).to.equal('The price is $2, not 2 €');
  });

  it('leaves missing variables as-is', () => {
    const original = 'The price is $%{price}';
    const result = replaceVariables(original, {});

    expect(result).to.equal(original);
  });
});

describe('I18n', () => {
  const { t } = new I18n({
    strings: {
      known: 'translation',
      messages: { one: 'one message', other: '%{count} messages' },
    },
  });

  describe('#t', () => {
    it('returns localized key value', () => {
      expect(t('known')).to.equal('translation');
    });

    it('falls back to key value', () => {
      expect(t('unknown')).to.equal('unknown');
    });

    describe('pluralization', () => {
      it('throws when count is not given', () => {
        expect(() => t('messages')).to.throw(TypeError);
      });

      it('returns single count', () => {
        expect(t('messages', { count: 1 })).to.equal('one message');
      });

      it('returns other count, with variables replaced', () => {
        expect(t('messages', { count: 2 })).to.equal('2 messages');
      });
    });
  });
});
