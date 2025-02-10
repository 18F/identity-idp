import { renderHook } from '@testing-library/react-hooks';
import { I18n } from '@18f/identity-i18n';
import useI18n from './use-i18n';
import I18nContext from './i18n-context';

describe('useI18n', () => {
  describe('t', () => {
    it('returns localized key value', () => {
      const { result } = renderHook(() => useI18n(), {
        wrapper: ({ children }) => (
          <I18nContext.Provider value={new I18n({ strings: { sample: 'translation' } })}>
            {children}
          </I18nContext.Provider>
        ),
      });

      const { t } = result.current;

      expect(t('sample')).to.equal('translation');
    });

    it('falls back to key value', () => {
      const { result } = renderHook(() => useI18n());

      const { t } = result.current;

      expect(t('sample')).to.equal('sample');
    });
  });
});
