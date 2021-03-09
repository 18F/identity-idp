import FormErrorMessage, {
  RequiredValueMissingError,
  intersperse,
} from '@18f/identity-document-capture/components/form-error-message';
import { UploadFormEntryError } from '@18f/identity-document-capture/services/upload';
import { render } from '../../../support/document-capture';

describe('document-capture/components/form-error-message', () => {
  describe('intersperse', () => {
    it('returns an interspersed array', () => {
      const original = ['a', 'b', 'c'];
      const result = intersperse(original, true);

      const expected = ['a', true, 'b', true, 'c'];
      expect(expected).to.not.equal(original);
      expect(result).to.deep.equal(expected);
    });
  });

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
