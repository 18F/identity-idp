import FileImage from '@18f/identity-document-capture/components/file-image';
import { render } from '../../../support/document-capture';

describe('document-capture/components/file-image', () => {
  it('renders span prior to load', () => {
    const { container } = render(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="image" />,
    );

    expect(container.childNodes).to.have.lengthOf(1);
    const loader = container.childNodes[0];
    expect(loader.nodeName).to.equal('SPAN');
    expect(Array.from(loader.classList.values())).to.have.members([
      'document-capture-file-image',
      'document-capture-file-image--loading',
    ]);
  });

  it('renders a given file object as an image', async () => {
    const { findByAltText } = render(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="image" />,
    );

    const image = await findByAltText('image');

    expect(image.getAttribute('src')).to.match(/^data:image\/png;base64,/);
    expect(Array.from(image.classList.values())).to.have.members(['document-capture-file-image']);
  });

  it('renders a a changed file object as an image', async () => {
    const { findByAltText, rerender } = render(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="first image" />,
    );

    await findByAltText('first image');

    rerender(
      <FileImage file={new window.File([''], 'demo', { type: 'image/png' })} alt="second image" />,
    );

    const image = await findByAltText('second image');

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

    expect(Array.from(image.classList.values())).to.have.members([
      'document-capture-file-image',
      'my-class',
    ]);
  });
});
