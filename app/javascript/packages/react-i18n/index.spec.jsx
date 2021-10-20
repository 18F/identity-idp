import { useContext } from 'react';
import { render } from '@testing-library/react';
import { renderHook } from '@testing-library/react-hooks';
import { I18nContext, useI18n } from './index.js';

describe('I18nContext', () => {
  it('defaults to empty object', () => {
    const { result } = renderHook(() => useContext(I18nContext));

    expect(result.current).to.deep.equal({});
  });
});

describe('useI18n', () => {
  describe('formatHTML', () => {
    let formatHTML;
    before(() => {
      const { result } = renderHook(() => useI18n());
      formatHTML = result.current.formatHTML;
    });

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
