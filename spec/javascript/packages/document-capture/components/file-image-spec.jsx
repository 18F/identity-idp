import FileImage from '@18f/identity-document-capture/components/file-image';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/file-image', () => {
  let file;
  before(async () => {
    file = await getFixtureFile('doc_auth_images/id-back.jpg');
  });

  it('renders span prior to load', () => {
    const { container } = render(<FileImage file={file} alt="image" />);

    expect(container.childNodes).to.have.lengthOf(1);
    const loader = container.childNodes[0];
    expect(loader.nodeName).to.equal('SPAN');
    expect(Array.from(loader.classList.values())).to.have.members([
      'document-capture-file-image',
      'document-capture-file-image--loading',
    ]);
  });

  it('renders a given file object as an image', async () => {
    const { findByAltText } = render(<FileImage file={file} alt="image" />);

    const image = await findByAltText('image');

    expect(image.getAttribute('src')).to.match(/^data:image\/jpeg;base64,/);
    expect(Array.from(image.classList.values())).to.have.members(['document-capture-file-image']);
  });

  it('renders a a changed file object as an image', async () => {
    const { findByAltText, rerender } = render(<FileImage file={file} alt="first image" />);

    await findByAltText('first image');

    rerender(<FileImage file={file} alt="second image" />);

    const image = await findByAltText('second image');

    expect(image.getAttribute('src')).to.match(/^data:image\/jpeg;base64,/);
  });

  it('renders with className', async () => {
    const { findByAltText } = render(<FileImage file={file} alt="image" className="my-class" />);

    const image = await findByAltText('image');

    expect(Array.from(image.classList.values())).to.have.members(['document-capture-file-image', 'my-class']);
  });
});
