import { render } from '@testing-library/react';
import TroubleshootingOptions from './troubleshooting-options';

describe('TroubleshootingOptions', () => {
  const DEFAULT_PROPS = {
    options: [
      { text: <>Option 1</>, url: `/1`, isExternal: true },
      { text: 'Option 2', url: `/2` },
    ],
  };

  it('renders the default heading', () => {
    const { getByRole } = render(<TroubleshootingOptions {...DEFAULT_PROPS} />);

    const heading = getByRole('heading');

    expect(heading.tagName).to.be.equal('H2');
    expect(heading.textContent).to.equal('components.troubleshooting_options.default_heading');
  });

  it('renders a given heading', () => {
    const { getByRole } = render(
      <TroubleshootingOptions {...DEFAULT_PROPS} heading="Need help?" />,
    );

    const heading = getByRole('heading');

    expect(heading.tagName).to.be.equal('H2');
    expect(heading.textContent).to.equal('Need help?');
  });

  it('renders a given headingTag', () => {
    const { getByRole } = render(<TroubleshootingOptions {...DEFAULT_PROPS} headingTag="h3" />);

    const heading = getByRole('heading');

    expect(heading.tagName).to.be.equal('H3');
  });

  it('renders given options', () => {
    const { getAllByRole } = render(<TroubleshootingOptions {...DEFAULT_PROPS} />);

    const links = getAllByRole('link') as HTMLAnchorElement[];

    expect(links).to.have.lengthOf(2);
    expect(links[0].textContent).to.equal('Option 1links.new_window');
    expect(links[0].getAttribute('href')).to.equal(`/1`);
    expect(links[0].target).to.equal('_blank');
    expect(links[1].textContent).to.equal('Option 2');
    expect(links[1].getAttribute('href')).to.equal(`/2`);
    expect(links[1].target).to.be.empty();
  });

  it('renders nothing if there are no options', () => {
    const { container } = render(<TroubleshootingOptions {...DEFAULT_PROPS} options={[]} />);

    expect(container.innerHTML).to.be.empty();
  });

  it('passes additional options props as link props', () => {
    const options = [{ text: 'Option', url: '/', 'data-example': true }];
    const { getByRole } = render(<TroubleshootingOptions {...DEFAULT_PROPS} options={options} />);

    const link = getByRole('link');

    expect(link.hasAttribute('data-example')).to.be.true();
  });

  it('renders with expected classes', () => {
    const { container } = render(<TroubleshootingOptions {...DEFAULT_PROPS} />);

    const element = container.firstElementChild!;

    expect(element.classList.contains('troubleshooting-options')).to.be.true();
  });
});
