import { render } from '@testing-library/react';
import BlockLink from './block-link';

describe('BlockLink', () => {
  const linkText = 'link text';
  const url = '/example';

  it('renders a link', () => {
    const { getByRole } = render(<BlockLink url={url}>{linkText}</BlockLink>);

    const link = getByRole('link');

    expect(link.hasAttribute('target')).to.be.false();
    expect(link.hasAttribute('rel')).to.be.false();
    expect(link.textContent).to.equal(linkText);
  });

  it('renders a link in a new tab', () => {
    const { getByRole } = render(
      <BlockLink url={url} isNewTab>
        {linkText}
      </BlockLink>,
    );

    const link = getByRole('link');

    expect(link.getAttribute('target')).to.equal('_blank');
    expect(link.getAttribute('rel')).to.equal('noreferrer');
    expect(link.textContent).to.equal(`${linkText} links.new_window`);
  });
});
