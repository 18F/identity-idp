import { I18nContext } from '@18f/identity-document-capture';
import FormErrorMessage, {
  RequiredValueMissingError,
} from '@18f/identity-document-capture/components/form-error-message';
import { UploadFormEntryError } from '@18f/identity-document-capture/services/upload';
import { BackgroundEncryptedUploadError } from '@18f/identity-document-capture/higher-order/with-background-encrypted-upload';
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

  it('returns formatted BackgroundEncryptedUploadError', () => {
    const { getByText } = render(
      <I18nContext.Provider
        value={{
          'doc_auth.errors.upload_error': 'Sorry, something went wrong on our end.',
          'errors.messages.try_again': 'Please try again.',
        }}
      >
        <FormErrorMessage error={new BackgroundEncryptedUploadError()} />
      </I18nContext.Provider>,
    );

    const message = getByText('Sorry, something went wrong on our end. Please try again.');
    expect(message).to.be.ok();
    expect(message.innerHTML.split('&nbsp;')).to.deep.equal([
      'Sorry, something went wrong on our end. Please',
      'try',
      'again.',
    ]);
  });

  it('returns null if error is of an unknown type', () => {
    const { container } = render(<FormErrorMessage error={new Error()} />);

    expect(container.childNodes).to.be.empty();
  });
});
