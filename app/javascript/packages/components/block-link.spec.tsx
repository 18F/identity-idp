import { render } from '@testing-library/react';
import BlockLink from './block-link';

describe('BlockLink', () => {
  it('renders a link with expected class name and arrow content', () => {
    const { getByRole } = render(<BlockLink href="/" />);

    const link = getByRole('link');

    expect(link.classList.contains('block-link')).to.be.true();
    expect(link.querySelector('.block-link__arrow')).to.exist();
  });

  context('with custom css class', () => {
    it('renders a link with expected class names', () => {
      const { getByRole } = render(<BlockLink href="/" className="my-custom-class" />);

      const link = getByRole('link');

      expect(link.classList.contains('block-link')).to.be.true();
      expect(link.classList.contains('my-custom-class')).to.be.true();
    });
  });
});
