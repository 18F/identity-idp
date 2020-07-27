import React from 'react';
import render from '../../../support/render';
import FileImage from '../../../../../app/javascript/app/document-capture/components/file-image';

describe('document-capture/components/file-image', () => {
  it('renders nothing prior to load', async () => {
    const { container } = render(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="image" />,
    );

    expect(container.childNodes).to.have.lengthOf(0);
  });

  it('renders a given file object as an image', async () => {
    const { findByAltText } = render(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="image" />,
    );

    const image = await findByAltText('image');

    expect(image.getAttribute('src')).to.match(/^data:image\/png;base64,/);
  });

  it('renders with extra props', async () => {
    const { findByAltText } = render(
      <FileImage
        file={new window.File([''], 'demo', { type: 'image/png' })}
        alt="image"
        data-example="ok"
      />,
    );

    const image = await findByAltText('image');

    expect(image.getAttribute('data-example')).to.be.ok();
  });
});
