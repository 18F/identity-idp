import React from 'react';
import FormErrorMessage, {
  RequiredValueMissingError,
} from '@18f/identity-document-capture/components/form-error-message';
import { UploadFormEntryError } from '@18f/identity-document-capture/services/upload';
import { render } from '../../../support/document-capture';

describe('document-capture/components/form-error-message', () => {
  it('returns formatted RequiredValueMissingError', () => {
    const { getByText } = render(<FormErrorMessage error={new RequiredValueMissingError()} />);

    expect(getByText('simple_form.required.text')).to.be.ok();
  });

  it('returns formatted UploadFormEntryError', () => {
    const { getByText } = render(
      <FormErrorMessage error={new UploadFormEntryError('Field is required')} />,
    );

    expect(getByText('Field is required')).to.be.ok();
  });

  it('returns null if error is of an unknown type', () => {
    const { container } = render(<FormErrorMessage error={new Error()} />);

    expect(container.childNodes).to.be.empty();
  });
});
