import { render } from '@testing-library/react';
import TroubleshootingOptions from './troubleshooting-options';

describe('TroubleshootingOptions', () => {
  it('renders the default heading', () => {
    const { getByRole } = render(<TroubleshootingOptions options={[]} />);

    const heading = getByRole('heading');

    expect(heading.tagName).to.be.equal('H2');
    expect(heading.textContent).to.equal('components.troubleshooting_options.default_heading');
  });

  it('renders a given heading', () => {
    const { getByRole } = render(<TroubleshootingOptions heading="Need help?" options={[]} />);

    const heading = getByRole('heading');

    expect(heading.tagName).to.be.equal('H2');
    expect(heading.textContent).to.equal('Need help?');
  });

  it('renders a given headingTag', () => {
    const { getByText } = render(
      <TroubleshootingOptions headingTag="h3" heading="Test Header" options={[]} />,
    );

    expect(getByText('Test Header').tagName).to.be.equal('H3');
  });

  it('renders given options', () => {
    const { getAllByRole } = render(
      <TroubleshootingOptions
        heading=""
        options={[
          { text: <>Option 1</>, url: 'https://example.com/1', isExternal: true },
          { text: 'Option 2', url: 'https://example.com/2' },
        ]}
      />,
    );

    const links = /** @type {HTMLAnchorElement[]} */ (getAllByRole('link'));

    expect(links).to.have.lengthOf(2);
    expect(links[0].textContent).to.equal('Option 1 links.new_window');
    expect(links[0].href).to.equal('https://example.com/1');
    expect(links[0].target).to.equal('_blank');
    expect(links[1].textContent).to.equal('Option 2');
    expect(links[1].href).to.equal('https://example.com/2');
    expect(links[1].target).to.be.empty();
  });

  it('renders a new features tag with isNewFeatures', () => {
    const { container, getByText } = render(
      <TroubleshootingOptions
        heading=""
        isNewFeatures
        options={[
          { text: <>Option 1</>, url: 'https://example.com/1', isExternal: true },
          { text: 'Option 2', url: 'https://example.com/2' },
        ]}
      />,
    );

    expect(
      container.firstElementChild?.classList.contains('troubleshooting-options--no-bar'),
    ).to.eq(true, 'it hides the visual bar');

    const tag = getByText('components.troubleshooting_options.new_feature');
    expect(tag.classList.contains('text-uppercase')).to.eq(true);
  });
});
