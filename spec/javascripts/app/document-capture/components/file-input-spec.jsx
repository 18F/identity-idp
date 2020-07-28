import React from 'react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import render from '../../../support/render';
import FileInput, {
  isImageFile,
} from '../../../../../app/javascript/app/document-capture/components/file-input';

describe('document-capture/components/file-input', () => {
  describe('isImageFile', () => {
    it('returns false if given file is not an image', () => {
      expect(isImageFile(new window.File([''], 'demo', { type: 'text/plain' }))).to.be.false();
    });

    it('returns true if given file is an image', () => {
      expect(isImageFile(new window.File([''], 'demo', { type: 'image/png' }))).to.be.true();
    });
  });

  it('renders file input with label', () => {
    const { getByLabelText } = render(<FileInput label="File" />);

    const input = getByLabelText('File');

    expect(input.nodeName).to.equal('INPUT');
    expect(input.type).to.equal('file');
  });

  it('renders an optional hint', () => {
    const { getByLabelText } = render(<FileInput label="File" hint="Must be small" />);

    const input = getByLabelText('File');
    const hint = document.getElementById(input.getAttribute('aria-describedby')).textContent;

    expect(hint).to.equal('Must be small');
  });

  it('renders a value preview', async () => {
    const { findByRole, getByLabelText } = render(
      <FileInput label="File" value={new window.File([''], 'demo', { type: 'image/png' })} />,
    );

    const preview = await findByRole('img', { hidden: true });
    const input = getByLabelText('File');

    expect(input).to.be.ok();
    expect(preview.getAttribute('src')).to.match(/^data:image\/png;base64,/);
  });

  it('does not render preview if value is not image', async () => {
    const { container } = render(
      <FileInput label="File" value={new window.File([''], 'demo', { type: 'text/plain' })} />,
    );

    expect(container.querySelector('.usa-file-input__preview')).to.not.be.ok();
  });

  it('limits to accepted file mime types', () => {
    const { getByLabelText } = render(
      <FileInput label="File" accept={['image/png', 'image/bmp']} />,
    );

    expect(getByLabelText('File').accept).to.equal('image/png,image/bmp');
  });

  it('calls onChange with next value', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const file = new window.File([''], 'upload.png', { type: 'image/png' });
    const input = getByLabelText('File');
    userEvent.upload(input, file);

    expect(onChange.getCall(0).args[0]).to.equal(file);
  });

  it('allows changing the selected value', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(<FileInput label="File" onChange={onChange} />);

    const file1 = new window.File([''], 'upload1.png', { type: 'image/png' });
    const file2 = new window.File([''], 'upload2.png', { type: 'image/png' });
    const input = getByLabelText('File');
    userEvent.upload(input, file1);
    userEvent.upload(input, file2);

    expect(onChange.getCall(0).args[0]).to.equal(file1);
    expect(onChange.getCall(1).args[0]).to.equal(file2);
  });

  it.skip('supports change by drag and drop', () => {});

  it.skip('shows an error state', () => {});
});
