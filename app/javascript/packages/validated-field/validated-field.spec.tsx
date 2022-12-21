import sinon from 'sinon';
import { render } from '@testing-library/react';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import AddressSearch from '@18f/identity-document-capture/components/address-search';
import ValidatedField, { getErrorMessages } from './validated-field';

describe('getErrorMessages', () => {
  context('undefined type', () => {
    it('returns the expected messages', () => {
      const messages = getErrorMessages();

      expect(messages).to.deep.equal({
        valueMissing: 'simple_form.required.text',
      });
    });
  });

  context('text type', () => {
    it('returns the expected messages', () => {
      const messages = getErrorMessages('text');

      expect(messages).to.deep.equal({
        valueMissing: 'simple_form.required.text',
      });
    });
  });

  context('checkbox type', () => {
    it('returns the expected messages', () => {
      const messages = getErrorMessages('checkbox');

      expect(messages).to.deep.equal({
        valueMissing: 'forms.validation.required_checkbox',
      });
    });
  });

  context('email type', () => {
    it('returns the expected messages', () => {
      const messages = getErrorMessages('email');

      expect(messages).to.deep.equal({
        valueMissing: 'simple_form.required.text',
        typeMismatch: 'valid_email.validations.email.invalid',
      });
    });
  });
});

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
    const { getByRole, rerender } = render(<ValidatedField validate={validate} />);

    const input = getByRole('textbox') as HTMLInputElement;
    input.reportValidity();

    expect(computeAccessibleDescription(input)).to.equal('oops');

    validate.resetBehavior();
    rerender(<ValidatedField validate={validate} required />);
    input.reportValidity();

    expect(computeAccessibleDescription(input)).to.equal('simple_form.required.text');
  });

  it('merges classNames', () => {
    const { getByRole } = render(<ValidatedField className="my-custom-class" />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.classList.contains('validated-field__input')).to.be.true();
    expect(input.classList.contains('my-custom-class')).to.be.true();
  });

  it('returns an input element which exposes the reportValidity function to parent element', () => {
    const validate = sinon.stub().throws(new Error('not an address, oh no'));
    const { getByRole } = render(
      <AddressSearch>
        <ValidatedField validate={validate} />
      </AddressSearch>,
    );

    const input = getByRole('textbox') as HTMLInputElement;
    input.reportValidity();
    expect(computeAccessibleDescription(input)).to.include(
      'in_person_proofing.body.location.inline_error',
    );
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
