import { render } from '@testing-library/react';
import BlockLink from '@18f/identity-document-capture/components/block-link';

describe('document-capture/components/block-link', () => {
  const linkText = 'link text';

  context('relative url', () => {
    const url = '/example';

    it('renders a link', () => {
      const { getByRole } = render(<BlockLink url={url}>{linkText}</BlockLink>);

      const link = getByRole('link');

      expect(link.hasAttribute('target')).to.be.false();
      expect(link.textContent).to.equal(linkText);
    });

    context('forced external', () => {
      it('renders a link', () => {
        const { getByRole } = render(
          <BlockLink url={url} isExternal>
            {linkText}
          </BlockLink>,
        );

        const link = getByRole('link');

        expect(link.getAttribute('target')).to.equal('_blank');
        expect(link.textContent).to.equal(`${linkText} links.new_window`);
      });
    });
  });

  context('same host url', () => {
    const url = new URL('/example', window.location.href).toString();

    it('renders a link', () => {
      const { getByRole } = render(<BlockLink url={url}>{linkText}</BlockLink>);

      const link = getByRole('link');

      expect(link.hasAttribute('target')).to.be.false();
      expect(link.textContent).to.equal(linkText);
    });

    context('forced external', () => {
      it('renders a link', () => {
        const { getByRole } = render(
          <BlockLink url={url} isExternal>
            {linkText}
          </BlockLink>,
        );

        const link = getByRole('link');

        expect(link.getAttribute('target')).to.equal('_blank');
        expect(link.textContent).to.equal(`${linkText} links.new_window`);
      });
    });
  });

  context('external url', () => {
    const url = 'http://external.example.com/example';

    it('renders a link', () => {
      const { getByRole } = render(<BlockLink url={url}>{linkText}</BlockLink>);

      const link = getByRole('link');

      expect(link.getAttribute('target')).to.equal('_blank');
      expect(link.textContent).to.equal(`${linkText} links.new_window`);
    });

    context('forced non-external', () => {
      it('renders a link', () => {
        const { getByRole } = render(
          <BlockLink url={url} isExternal={false}>
            {linkText}
          </BlockLink>,
        );

        const link = getByRole('link');

        expect(link.hasAttribute('target')).to.be.false();
        expect(link.textContent).to.equal(linkText);
      });
    });
  });
});
