import { createRef } from 'react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { fireEvent } from '@testing-library/react';
import { expect } from 'chai';
import FileInput, {
  getAcceptPattern,
  isImage,
  isValidForAccepts,
} from '@18f/identity-document-capture/components/file-input';
import DeviceContext from '@18f/identity-document-capture/context/device';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/file-input', () => {
  let file;
  before(async () => {
    file = await getFixtureFile('doc_auth_images/id-front.jpg');
  });

  describe('getAcceptPattern', () => {
    it('returns a pattern for audio matching', () => {
      const accept = 'audio/*';
      const pattern = getAcceptPattern(accept);

      expect(pattern.test('audio/mp3')).to.be.true();
      expect(pattern.test('xaudio/mp3')).to.be.false();
      expect(pattern.test('video/mp4')).to.be.false();
      expect(pattern.test('image/jpg')).to.be.false();
    });

    it('returns a pattern for video matching', () => {
      const accept = 'video/*';
      const pattern = getAcceptPattern(accept);

      expect(pattern.test('video/mp4')).to.be.true();
      expect(pattern.test('xvideo/mp4')).to.be.false();
      expect(pattern.test('audio/mp3')).to.be.false();
      expect(pattern.test('image/jpg')).to.be.false();
    });

    it('returns a pattern for image matching', () => {
      const accept = 'image/*';
      const pattern = getAcceptPattern(accept);

      expect(pattern.test('image/jpg')).to.be.true();
      expect(pattern.test('ximage/jpg')).to.be.false();
      expect(pattern.test('audio/mp3')).to.be.false();
      expect(pattern.test('video/mp4')).to.be.false();
    });

    it('returns a pattern for mime type matching', () => {
      const accept = 'image/jpeg';
      const pattern = getAcceptPattern(accept);

      expect(pattern.test('image/jpeg')).to.be.true();
      expect(pattern.test('ximage/jpeg')).to.be.false();
      expect(pattern.test('audio/mp3')).to.be.false();
      expect(pattern.test('video/mp4')).to.be.false();
    });

    it('returns undefined for unknown accept', () => {
      const accept = 'jpg';
      const pattern = getAcceptPattern(accept);

      expect(pattern).to.be.undefined();
    });

    it('returns undefined for file extension matching', () => {
      const accept = '.jpg';
      const pattern = getAcceptPattern(accept);

      expect(pattern).to.be.undefined();
    });
  });

  describe('isImage', () => {
    context('file', () => {
      it('returns false if not an image', () => {
        expect(isImage(new window.File([], 'demo.txt', { type: 'text/plain' }))).to.be.false();
      });

      it('returns true if an image', () => {
        expect(isImage(new window.File([], 'demo.png', { type: 'image/png' }))).to.be.true();
      });
    });

    context('data URL', () => {
      it('returns false if not an image', () => {
        expect(isImage('data:text/plain;base64,8J+Riw==')).to.be.false();
      });

      it('returns true if an image', () => {
        expect(isImage('data:image/jpeg;base64,8J+Riw==')).to.be.true();
      });
    });
  });

  describe('isValidForAccepts', () => {
    it('returns false if invalid', () => {
      const url = 'text/plain';
      const accept = ['image/*'];

      expect(isValidForAccepts(url, accept)).to.be.false();
    });

    it('returns true if valid', () => {
      const url = 'image/gif';
      const accept = ['image/*'];

      expect(isValidForAccepts(url, accept)).to.be.true();
    });

    it('returns true if accept is nullish', () => {
      const url = 'image/gif';
      const accept = null;

      expect(isValidForAccepts(url, accept)).to.be.true();
    });
  });

  it('renders file input with label', () => {
    const { getByLabelText } = render(<FileInput label="File" />);

    const input = getByLabelText('File');

    expect(input.nodeName).to.equal('INPUT');
    expect(input.type).to.equal('file');
  });

  it('renders decorative banner text', () => {
    const { getByText } = render(
      <FileInput label="File" bannerText="File Goes Here" className="my-custom-class" />,
    );

    expect(getByText('File Goes Here', { hidden: true })).to.be.ok();
  });

  it('renders an optional hint', () => {
    const { getByLabelText } = render(<FileInput label="File" hint="Must be small" />);

    const input = getByLabelText('File');
    const hintId = input.getAttribute('aria-describedby');
    const hint = document.getElementById(hintId).textContent;

    expect(hint).to.equal('Must be small');
  });

  it('renders a value preview for a blob', async () => {
    const { container, findByRole, getByLabelText } = render(
      <FileInput label="File" value={new window.Blob([file], { type: 'image/jpeg' })} />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/jpeg;base64,/);
    expect(container.querySelector('.usa-file-input__preview-heading').textContent).to.equal(
      'doc_auth.forms.change_file',
    );
  });

  it('renders a value preview for a file', async () => {
    const { container, findByRole, getByLabelText } = render(
      <FileInput label="File" value={file} />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/jpeg;base64,/);
    expect(container.querySelector('.usa-file-input__preview-heading').textContent).to.equal(
      'doc_auth.forms.selected_file: id-front.jpg doc_auth.forms.change_file',
    );
  });

  it('renders a value preview for a data URL', async () => {
    const { container, findByRole, getByLabelText } = render(
      <FileInput
        label="File"
        value="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVQYV2NgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII="
      />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/png;base64,/);
    expect(container.querySelector('.usa-file-input__preview-heading').textContent).to.equal(
      'doc_auth.forms.change_file',
    );
  });

  it('does not render preview if value is not image', () => {
    const { container } = render(
      <FileInput label="File" value={new window.File([], 'demo.txt', { type: 'text/plain' })} />,
    );

    expect(container.querySelector('.usa-file-input__preview')).to.not.be.ok();
  });

  it('limits to accepted file mime types', () => {
    const { getByLabelText } = render(
      <FileInput label="File" accept={['image/png', 'image/bmp']} />,
    );

    expect(getByLabelText('File').accept).to.equal('image/png,image/bmp');
  });

  it('calls onChange with next value', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const input = getByLabelText('File');
    await userEvent.upload(input, file);

    expect(onChange.getCall(0).args[0]).to.equal(file);
  });

  it('has aria-describedby set to null by default', () => {
    const { getByLabelText } = render(<FileInput label="File" />);
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.null();
  });

  it('has aria-describedby set to hintId when hint shown and neither success or error shown', () => {
    const { getByLabelText, container } = render(<FileInput label="File" hint="Must be small" />);

    const labelElement = container.querySelector('.usa-hint');
    const hintId = labelElement.getAttribute('id');
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.equal(hintId);
  });

  it('has aria-describedby set to errorId when only error message shown', () => {
    const props = { fileUpdatedText: 'File updated', label: 'File', errorMessage: 'Oops!' };
    const { getByLabelText, container } = render(<FileInput {...props} />);

    // Extract the id of the error message
    const errorMessageElement = container.querySelector('.usa-error-message');
    const errorId = errorMessageElement.getAttribute('id');

    // Now check that the aria-describedby is what we expect
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.equal(errorId);
  });

  it('has aria-describedby set to successId when only success message shown', () => {
    const file2 = new window.File([file], 'file2.jpg');
    const props = { fileUpdatedText: 'File updated', label: 'File' };
    const { getByText, getByLabelText, container, rerender } = render(<FileInput {...props} />);

    // The success message doesn't appear until the second file is uploaded successfully (AKA updated)
    rerender(<FileInput {...props} value={file} />);
    expect(() => getByText('File updated')).to.throw();

    // Mock uploading the second file successfully
    rerender(<FileInput {...props} value={file2} />);
    expect(getByText('File updated')).to.be.ok();

    // Extract the id of the success message
    const successMessageElement = container.querySelector('.usa-success-message');
    const successId = successMessageElement.getAttribute('id');

    // Now check that the aria-describedby is what we expect
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.equal(successId);
  });

  it('has aria-describedby set to combination of errorId and hintId when hint and error shown', () => {
    const props = {
      fileUpdatedText: 'File updated',
      label: 'File',
      hint: 'Must be small',
      errorMessage: 'Oops!',
    };
    const { getByLabelText, container } = render(<FileInput {...props} />);

    // Extract the ids of the hint and error message
    const labelElement = container.querySelector('.usa-hint');
    const hintId = labelElement.getAttribute('id');
    const errorMessageElement = container.querySelector('.usa-error-message');
    const errorId = errorMessageElement.getAttribute('id');

    // Now check that the aria-describedby is what we expect
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.equal(`${errorId} ${hintId}`);
  });

  it('has aria-describedby set to combination of successId and hintId when hint and success shown', () => {
    const file2 = new window.File([file], 'file2.jpg');
    const props = { fileUpdatedText: 'File updated', label: 'File', hint: 'Must be small' };
    const { getByText, getByLabelText, container, rerender } = render(<FileInput {...props} />);

    // The success message doesn't appear until the second file is uploaded successfully (AKA updated)
    rerender(<FileInput {...props} value={file} />);
    expect(() => getByText('File updated')).to.throw();

    // Mock uploading the second file successfully
    rerender(<FileInput {...props} value={file2} />);
    expect(getByText('File updated')).to.be.ok();

    // Extract the ids of the hint and success message
    const labelElement = container.querySelector('.usa-hint');
    const hintId = labelElement.getAttribute('id');
    const successMessageElement = container.querySelector('.usa-success-message');
    const successId = successMessageElement.getAttribute('id');

    // Now check that the aria-describedby is what we expect
    const input = getByLabelText('File');
    expect(input.getAttribute('aria-describedby')).to.be.equal(`${successId} ${hintId}`);
  });

  it('calls onClick when clicked', async () => {
    const onClick = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onClick={onClick} />);

    const input = getByLabelText('File');
    await userEvent.click(input);

    expect(onClick).to.have.been.calledOnce();
  });

  it('calls onDrop when receiving drop event', () => {
    const onDrop = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onDrop={onDrop} />);

    const input = getByLabelText('File');
    fireEvent.drop(input);

    expect(onDrop).to.have.been.calledOnce();
  });

  it('allows changing the selected value', async () => {
    const file2 = new window.File([file], 'file2.jpg');
    const onChange = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const input = getByLabelText('File');
    await userEvent.upload(input, file);
    await userEvent.upload(input, file2);

    expect(onChange.getCall(0).args[0]).to.equal(file);
    expect(onChange.getCall(1).args[0]).to.equal(file2);
  });

  it('allows clearing the selected value', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const input = getByLabelText('File');
    await userEvent.upload(input, file);
    await userEvent.upload(input, []);
    expect(onChange.getCall(1).args[0]).to.be.null();
    expect(input.value).to.be.empty();
  });

  it('omits desktop-relevant details in mobile context', async () => {
    const { container, getByText, findByRole, rerender } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput label="File" />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.forms.choose_file_html', { hidden: true })).to.throw();

    rerender(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput label="File" bannerText="File goes here" />
      </DeviceContext.Provider>,
    );

    expect(() => getByText('doc_auth.forms.choose_file_html', { hidden: true })).to.throw();
    expect(getByText('File goes here', { hidden: true })).to.be.ok();

    rerender(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput
          label="File"
          bannerText="File goes here"
          value="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVQYV2NgYAAAAAMAAWgmWQ0AAAAASUVORK5CYII="
        />
      </DeviceContext.Provider>,
    );

    await findByRole('img', { hidden: true });
    expect(container.querySelector('.usa-file-input__preview-heading')).to.not.be.ok();
  });

  it('adds drag effects', () => {
    const { getByLabelText } = render(<FileInput label="File" />);

    const input = getByLabelText('File');
    const container = input.closest('.usa-file-input');

    fireEvent.dragOver(input);
    expect(container.classList.contains('usa-file-input--drag')).to.be.true();

    fireEvent.dragLeave(input);
    expect(container.classList.contains('usa-file-input--drag')).to.be.false();

    fireEvent.dragOver(input);
    expect(container.classList.contains('usa-file-input--drag')).to.be.true();

    fireEvent.drop(input);
    expect(container.classList.contains('usa-file-input--drag')).to.be.false();
  });

  it('shows an error state', async () => {
    const onChange = sinon.stub();
    const onError = sinon.stub();
    const { getByLabelText, getByText } = render(
      <FileInput
        label="File"
        accept={['text/*']}
        invalidTypeText="Invalid type"
        onChange={onChange}
        onError={onError}
      />,
    );

    const input = getByLabelText('File');
    await userEvent.upload(input, file, { applyAccept: false });

    expect(getByText('Invalid type')).to.be.ok();
    expect(onError.getCall(0).args[0]).to.equal('Invalid type');
  });

  it('allows customization of invalid file type error message', async () => {
    const onChange = sinon.stub();
    const onError = sinon.stub();
    const { getByLabelText, getByText } = render(
      <FileInput
        label="File"
        accept={['text/*']}
        onChange={onChange}
        onError={onError}
        invalidTypeText="Wrong type"
      />,
    );

    const input = getByLabelText('File');
    await userEvent.upload(input, file, { applyAccept: false });

    expect(getByText('Wrong type')).to.be.ok();
    expect(onError.getCall(0).args[0]).to.equal('Wrong type');
  });

  it('shows an error from rendering parent', async () => {
    const onChange = sinon.stub();
    const onError = sinon.stub();
    const props = {
      label: 'File',
      accept: ['text/*'],
      onChange,
      onError,
      invalidTypeText: 'Invalid type',
    };
    const { getByLabelText, getByText, rerender } = render(<FileInput {...props} />);

    const input = getByLabelText('File');
    await userEvent.upload(input, file, { applyAccept: false });

    expect(getByText('Invalid type')).to.be.ok();
    expect(onError.getCall(0).args[0]).to.equal('Invalid type');

    rerender(<FileInput {...props} errorMessage="Oops!" />);

    expect(getByText('Oops!')).to.be.ok();
    expect(() => getByText('Invalid type')).to.throw();
    expect(onError.callCount).to.equal(1);
  });

  it('shows an updated state', () => {
    const file2 = new window.File([file], 'file2.jpg');

    const props = { fileUpdatedText: 'File updated', label: 'File' };

    const { getByText, rerender } = render(<FileInput {...props} />);

    expect(() => getByText('File updated')).to.throw();

    rerender(<FileInput {...props} value={file} />);

    expect(() => getByText('File updated')).to.throw();

    rerender(<FileInput {...props} value={file} />);

    expect(() => getByText('File updated')).to.throw();

    rerender(<FileInput {...props} value={file2} />);

    expect(getByText('File updated')).to.be.ok();

    rerender(<FileInput {...props} value={file2} />);

    expect(getByText('File updated')).to.be.ok();
  });

  it('forwards ref', () => {
    const ref = createRef();
    render(<FileInput ref={ref} label="File" />);

    expect(ref.current.nodeName).to.equal('INPUT');
  });

  it('renders pending value', () => {
    const { getByLabelText, queryByRole, queryByText, container } = render(
      <FileInput
        bannerText="Banner"
        fileLoadingText="File loading"
        value={file}
        label="File"
        isValuePending
      />,
    );
    const input = getByLabelText('File');

    expect(container.querySelector('.usa-file-input--value-pending')).to.exist();
    expect(container.querySelector('.usa-file-input--has-value')).not.to.exist();
    expect(container.querySelector('.usa-file-input__preview-heading')).not.to.exist();
    expect(queryByRole('img', { hidden: true })).not.to.exist();
    expect(queryByText('File loading').classList.contains('usa-sr-only')).to.be.true();
    expect(container.querySelector('.spinner-dots')).to.exist();
    expect(queryByText('Banner')).not.to.exist();
    expect(input.getAttribute('aria-busy')).to.equal('true');
  });

  it('renders updated status', () => {
    const { getByText, rerender } = render(
      <FileInput fileLoadedText="File loaded" value={file} isValuePending />,
    );

    rerender(<FileInput fileLoadedText="File loaded" value={file} />);

    expect(getByText('File loaded').classList.contains('usa-sr-only')).to.be.true();
  });

  it('shows the file name on mobile for a yaml file', async () => {
    const ymlFile = await getFixtureFile('ial2_test_credential.yml');
    const { container } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput label="File" value={ymlFile} />
      </DeviceContext.Provider>,
    );
    expect(container.querySelector('.usa-file-input__preview-heading')).to.be.ok();
  });

  it('doesnt show the file name on mobile for an image file', () => {
    const { container } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput label="File" value={file} />
      </DeviceContext.Provider>,
    );
    expect(container.querySelector('.usa-file-input__preview-heading')).to.not.be.ok();
  });
});
