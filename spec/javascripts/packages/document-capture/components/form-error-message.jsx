import React from 'react';
import { RequiredValueMissingError } from '@18f/identity-document-capture/components/form-steps';
import FormErrorMessage from '@18f/identity-document-capture/components/form-error-message';
import render from '../../../support/render';

describe('document-capture/components/form-error-message', () => {
  it('returns formatted RequiredValueMissingError', () => {
    const { getByText } = render(<FormErrorMessage error={new RequiredValueMissingError()} />);

    expect(getByText('simple_form.required.text')).to.be.ok();
  });

  it('returns null if error is of an unknown type', () => {
    const { container } = render(<FormErrorMessage error={new Error()} />);

    expect(container.childNodes).to.be.empty();
  });
});
