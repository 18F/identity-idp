import sinon from 'sinon';
import { render } from '@testing-library/react';
import ValidatedField from './validated-field';

describe('ValidatedField', () => {
  it('renders a validated input', () => {
    const { getByRole } = render(<ValidatedField />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.getAttribute('aria-invalid')).to.equal('false');
    expect(input.checkValidity()).to.be.true();
  });

  it('validates using validate prop', () => {
    const validate = sinon.stub().throws(new Error('oops'));
    const { getByRole } = render(<ValidatedField validate={validate} />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.checkValidity()).to.be.false();
    expect(input.validationMessage).to.equal('oops');
  });

  it('validates using native validation', () => {
    const validate = sinon.stub();
    const { getByRole } = render(<ValidatedField validate={validate} required />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.checkValidity()).to.be.false();
    expect(input.validity.valueMissing).to.be.true();
  });

  it('is described by associated error message', () => {
    const validate = sinon.stub().throws(new Error('oops'));
    const { getByRole, baseElement } = render(<ValidatedField validate={validate} />);

    const input = getByRole('textbox') as HTMLInputElement;
    input.reportValidity();

    const errorMessage = baseElement.querySelector(`#${input.getAttribute('aria-describedby')}`)!;
    expect(errorMessage.classList.contains('usa-error-message')).to.be.true();
    expect(errorMessage.textContent).to.equal('oops');
  });

  it('merges classNames', () => {
    const { getByRole } = render(<ValidatedField className="my-custom-class" />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.classList.contains('validated-field__input')).to.be.true();
    expect(input.classList.contains('my-custom-class')).to.be.true();
  });

  context('with children', () => {
    it('validates using validate prop', () => {
      const validate = sinon.stub().throws(new Error('oops'));
      const { getByRole } = render(
        <ValidatedField validate={validate}>
          <input />
        </ValidatedField>,
      );

      const input = getByRole('textbox') as HTMLInputElement;

      expect(input.checkValidity()).to.be.false();
      expect(input.validationMessage).to.equal('oops');
    });

    it('merges classNames', () => {
      const { getByRole } = render(
        <ValidatedField>
          <input className="my-custom-class" />
        </ValidatedField>,
      );

      const input = getByRole('textbox') as HTMLInputElement;

      expect(input.classList.contains('validated-field__input')).to.be.true();
      expect(input.classList.contains('my-custom-class')).to.be.true();
    });
  });
});
