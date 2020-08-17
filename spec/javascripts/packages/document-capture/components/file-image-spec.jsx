import React from 'react';
import FileImage from '@18f/identity-document-capture/components/file-image';
import render from '../../../support/render';

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

  it('renders with className', async () => {
    const { findByAltText } = render(
      <FileImage
        file={new window.File([''], 'demo', { type: 'image/png' })}
        alt="image"
        className="my-class"
      />,
    );

    const image = await findByAltText('image');

    expect(image.classList.contains('my-class')).to.be.true();
  });
});
