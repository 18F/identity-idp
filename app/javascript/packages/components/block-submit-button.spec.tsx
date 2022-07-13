import { render } from '@testing-library/react';
import BlockSubmitButton from './block-submit-button';

describe('BlockSubmitButton', () => {
  const buttonLabel = 'Click here to submit';

  it('renders a button with an expected class name, type, and arrow content', () => {
    const { getByRole } = render(<BlockSubmitButton>{buttonLabel}</BlockSubmitButton>);

    const button = getByRole('button') as HTMLInputElement;

    expect(button.classList.contains('block-submit-button')).to.be.true();
    expect(button.querySelector('.block-link__arrow')).to.exist();
    expect(button.textContent).to.equal(buttonLabel);
    expect(button.type).to.equal('submit');
  });

  context('with custom css class', () => {
    it('renders a link with passed class name', () => {
      const { getByRole } = render(
        <BlockSubmitButton className="my-custom-class">{buttonLabel}</BlockSubmitButton>,
      );

      const button = getByRole('button');

      expect(button.classList.contains('block-submit-button')).to.be.true();
      expect(button.classList.contains('my-custom-class')).to.be.true();
    });
  });
});
