import { render } from '@testing-library/react';
import formatHTML from './format-html';

describe('formatHTML', () => {
  it('returns html string treated as escaped text without handler', () => {
    const formatted = formatHTML('Hello <strong>world</strong>!', {});

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Hello &lt;strong&gt;world&lt;/strong&gt;!');
  });

  it('returns html string chunked by component handlers', () => {
    const formatted = formatHTML('Hello <strong>world</strong>!', {
      strong: ({ children }) => <strong>{children}</strong>,
    });

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Hello <strong>world</strong>!');
  });

  it('returns html string chunked by string handlers', () => {
    const formatted = formatHTML('Hello <strong>world</strong>!', {
      strong: 'strong',
    });

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Hello <strong>world</strong>!');
  });

  it('returns html string chunked by multiple handlers', () => {
    const formatted = formatHTML('Message: <lg-custom>Hello</lg-custom> <strong>world</strong>!', {
      'lg-custom': () => <>Greetings</>,
      strong: ({ children }) => <strong>{children}</strong>,
    });

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Message: Greetings <strong>world</strong>!');
  });

  it('removes dangling empty text fragment', () => {
    const formatted = formatHTML('Hello <strong>world</strong>', {
      strong: ({ children }) => <strong>{children}</strong>,
    });

    const { container } = render(<>{formatted}</>);

    expect(container.childNodes).to.have.lengthOf(2);
  });

  it('allows (but discards) attributes in the input string', () => {
    const formatted = formatHTML(
      '<strong data-before>Hello</strong> <strong data-before>world</strong>',
      {
        strong: ({ children }) => <strong data-after>{children}</strong>,
      },
    );

    const { container } = render(<>{formatted}</>);

    expect(container.querySelectorAll('[data-after]')).to.have.lengthOf(2);
    expect(container.querySelectorAll('[data-before]')).to.have.lengthOf(0);
  });

  it('supports self-closing (void) elements', () => {
    const formatted = formatHTML('Hello<br /><br/><em>world</em>!', { br: 'br', em: 'em' });

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Hello<br><br><em>world</em>!');
  });
});
