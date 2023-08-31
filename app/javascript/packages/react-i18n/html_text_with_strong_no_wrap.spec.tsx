import { render } from '@testing-library/react';
import HtmlTextWithStrongNoWrap from './html_text_with_strong_no_wrap';

describe('htmlTextWithStrongNoWrap', () => {
  it('returns html string with rewritten strong tag', () => {
    const formatted = <HtmlTextWithStrongNoWrap text="Hello <strong>world</strong>!" />;

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal('Hello <strong class="text-no-wrap">world</strong>!');
  });

  it('return original string when no strong tag', () => {
    const expected = 'Hello world!';
    const formatted = <HtmlTextWithStrongNoWrap text={expected} />;

    const { container } = render(<>{formatted}</>);

    expect(container.innerHTML).to.equal(expected);
  });
});
