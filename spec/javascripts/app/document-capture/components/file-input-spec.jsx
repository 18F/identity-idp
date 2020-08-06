import React from 'react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { expect } from 'chai';
import render from '../../../support/render';
import FileInput, {
  isImage,
  toDataURL,
} from '../../../../../app/javascript/app/document-capture/components/file-input';
import DeviceContext from '../../../../../app/javascript/app/document-capture/context/device';
import DataURLFile from '../../../../../app/javascript/app/document-capture/models/data-url-file';

describe('document-capture/components/file-input', () => {
  describe('isImage', () => {
    it('returns false if given file is not an image', () => {
      expect(isImage('data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==')).to.be.false();
    });

    it('returns false if given file is not an image (data url string)', () => {
      expect(
        isImage('data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'),
      ).to.be.true();
    });
  });

  describe('toDataURL', () => {
    it('returns a promise resolving to the data URL representation of the file', async () => {
      const dataURL = await toDataURL(new window.File([''], 'upload.png', { type: 'image/png' }));
      expect(dataURL).to.equal('data:image/png;base64,');
    });
  });

  it('renders with custom className', () => {
    const { container } = render(<FileInput label="File" className="my-custom-class" />);

    expect(container.firstChild.classList.contains('my-custom-class')).to.be.true();
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
    const hint = document.getElementById(input.getAttribute('aria-describedby')).textContent;

    expect(hint).to.equal('Must be small');
  });

  it('renders a value preview for a file with name assigned', async () => {
    const { container, findByRole, getByLabelText } = render(
      <FileInput label="File" value={new DataURLFile('data:image/png;base64,', 'demo.png')} />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/png;base64,/);
    expect(container.querySelector('.usa-file-input__preview-heading').textContent).to.equal(
      'doc_auth.forms.selected_file: demo.png doc_auth.forms.change_file',
    );
  });

  it('renders a value preview for a file with name not assigned', async () => {
    const { container, findByRole, getByLabelText } = render(
      <FileInput label="File" value={new DataURLFile('data:image/png;base64,')} />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/png;base64,/);
    expect(container.querySelector('.usa-file-input__preview-heading').textContent).to.equal(
      'doc_auth.forms.change_file',
    );
  });

  it('does not render preview if value is not image', async () => {
    const { container } = render(
      <FileInput label="File" value={new DataURLFile('data:text/plain;base64,', 'demo.txt')} />,
    );

    expect(container.querySelector('.usa-file-input__preview')).to.not.be.ok();
  });

  it('limits to accepted file mime types', () => {
    const { getByLabelText } = render(
      <FileInput label="File" accept={['image/png', 'image/bmp']} />,
    );

    expect(getByLabelText('File').accept).to.equal('image/png,image/bmp');
  });

  it('calls onChange with next value', (done) => {
    const file = new window.File([''], 'upload.png', { type: 'image/png' });
    const onChange = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const input = getByLabelText('File');
    userEvent.upload(input, file);

    onChange.callsFake((nextValue) => {
      expect(nextValue.name).to.equal('upload.png');
      expect(nextValue.data).to.equal('data:image/png;base64,');
      done();
    });
  });

  it('allows changing the selected value', (done) => {
    const file1 = new window.File([''], 'upload1.png', { type: 'image/png' });
    const file2 = new window.File([''], 'upload2.png', { type: 'image/png' });
    const onChange = sinon.stub();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const input = getByLabelText('File');
    userEvent.upload(input, file1);
    onChange.onCall(0).callsFake((nextValue) => {
      expect(nextValue.name).to.equal('upload1.png');
      expect(nextValue.data).to.equal('data:image/png;base64,');
      userEvent.upload(input, file2);
    });

    onChange.onCall(1).callsFake((nextValue) => {
      expect(nextValue.name).to.equal('upload2.png');
      expect(nextValue.data).to.equal('data:image/png;base64,');
      done();
    });
  });

  it('omits desktop-relevant details in mobile context', async () => {
    const { container, getByText, findByRole, rerender } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <FileInput label="File" />
      </DeviceContext.Provider>,
    );

    expect(getByText('doc_auth.forms.choose_file_html', { hidden: true })).to.be.ok();

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
          value={new DataURLFile('data:image/png;base64,', 'demo.png')}
        />
      </DeviceContext.Provider>,
    );

    await findByRole('img', { hidden: true });
    expect(container.querySelector('.usa-file-input__preview-heading')).to.not.be.ok();
  });

  it.skip('supports change by drag and drop', () => {});

  it.skip('shows an error state', () => {});
});
