import { renderHook } from '@testing-library/react-hooks';
import I18nContext from '@18f/identity-document-capture/context/i18n';
import useI18n, { formatHTML } from '@18f/identity-document-capture/hooks/use-i18n';
import { render } from '../../../support/document-capture';

describe('document-capture/hooks/use-i18n', () => {
  describe('formatHTML', () => {
    it('returns html string treated as escaped text without handler', () => {
      const formatted = formatHTML('Hello <strong>world</strong>!', {});

      const { container } = render(formatted);

      expect(container.innerHTML).to.equal('Hello &lt;strong&gt;world&lt;/strong&gt;!');
    });

    it('returns html string chunked by component handlers', () => {
      const formatted = formatHTML('Hello <strong>world</strong>!', {
        strong: ({ children }) => <strong>{children}</strong>,
      });

      const { container } = render(formatted);

      expect(container.innerHTML).to.equal('Hello <strong>world</strong>!');
    });

    it('returns html string chunked by string handlers', () => {
      const formatted = formatHTML('Hello <strong>world</strong>!', {
        strong: 'strong',
      });

      const { container } = render(formatted);

      expect(container.innerHTML).to.equal('Hello <strong>world</strong>!');
    });

    it('returns html string chunked by multiple handlers', () => {
      const formatted = formatHTML(
        'Message: <lg-custom>Hello</lg-custom> <strong>world</strong>!',
        {
          'lg-custom': () => 'Greetings',
          strong: ({ children }) => <strong>{children}</strong>,
        },
      );

      const { container } = render(formatted);

      expect(container.innerHTML).to.equal('Message: Greetings <strong>world</strong>!');
    });

    it('removes dangling empty text fragment', () => {
      const formatted = formatHTML('Hello <strong>world</strong>', {
        strong: ({ children }) => <strong>{children}</strong>,
      });

      const { container } = render(formatted);

      expect(container.childNodes).to.have.lengthOf(2);
    });

    it('allows (but discards) attributes in the input string', () => {
      const formatted = formatHTML(
        '<strong data-before>Hello</strong> <strong data-before>world</strong>',
        {
          strong: ({ children }) => <strong data-after>{children}</strong>,
        },
      );

      const { container } = render(formatted);

      expect(container.querySelectorAll('[data-after]')).to.have.lengthOf(2);
      expect(container.querySelectorAll('[data-before]')).to.have.lengthOf(0);
    });
  });

  describe('t', () => {
    it('returns localized key value', () => {
      const { result } = renderHook(() => useI18n(), {
        wrapper: ({ children }) => (
          <I18nContext.Provider value={{ sample: 'translation' }}>{children}</I18nContext.Provider>
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
