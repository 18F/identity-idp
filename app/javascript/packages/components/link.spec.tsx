import { render } from '@testing-library/react';
import Link, { isExternalURL } from './link';

describe('isExternalURL', () => {
  it('returns true if host name is different', () => {
    const result = isExternalURL('http://example.com', 'http://example.test');

    expect(result).to.be.true();
  });

  it('returns false if host name is same', () => {
    const result = isExternalURL('http://example.com', 'http://example.com');

    expect(result).to.be.false();
  });

  it('returns false if candidate url cannot be parsed', () => {
    const result = isExternalURL('/', 'http://example.com');

    expect(result).to.be.false();
  });

  it('returns false if current url cannot be parsed', () => {
    const result = isExternalURL('http://example.com', '');

    expect(result).to.be.false();
  });
});

describe('Link', () => {
  it('renders link', () => {
    const { getByRole } = render(<Link href="/">Example</Link>);

    const link = getByRole('link', { name: 'Example' }) as HTMLAnchorElement;

    expect(link.getAttribute('href')).to.equal('/');
    expect(link.target).to.equal('');
    expect([...link.classList.values()]).to.have.all.members(['usa-link']);
  });

  it('forwards extra props to underlying anchor element', () => {
    const { getByRole } = render(<Link data-foo="bar" href="/" />);

    const link = getByRole('link');

    expect(link.getAttribute('data-foo')).to.equal('bar');
  });

  context('with custom css class', () => {
    it('renders link with class', () => {
      const { getByRole } = render(<Link href="/" className="my-custom-class" />);

      const link = getByRole('link') as HTMLAnchorElement;

      expect(link.classList.contains('my-custom-class')).to.be.true();
    });
  });

  context('with isExternal prop', () => {
    it('renders link which includes external link styles', () => {
      const { getByRole } = render(<Link href="/" isExternal />);

      const link = getByRole('link') as HTMLAnchorElement;

      expect([...link.classList.values()]).to.have.all.members(['usa-link', 'usa-link--external']);
    });

    it('renders link which opens in new tab', () => {
      const { getByRole } = render(<Link href="/" isExternal />);

      const link = getByRole('link') as HTMLAnchorElement;

      expect(link.target).to.equal('_blank');
      expect(link.rel).to.equal('noreferrer');
    });

    context('with explicitly-false isNewTab prop', () => {
      it('renders link which does not open in new tab', () => {
        const { getByRole } = render(<Link href="/" isExternal isNewTab={false} />);

        const link = getByRole('link') as HTMLAnchorElement;

        expect(link.target).to.equal('');
      });
    });
  });

  context('with isNewTab prop', () => {
    it('renders link which opens in new tab', () => {
      const { getByRole } = render(<Link href="/" isNewTab />);

      const link = getByRole('link') as HTMLAnchorElement;

      expect(link.target).to.equal('_blank');
      expect(link.rel).to.equal('noreferrer');
    });

    it('includes additional text hint for assistive technology', () => {
      const { getByRole } = render(
        <Link href="/" isNewTab>
          Example
        </Link>,
      );

      const link = getByRole('link', { name: 'Example links.new_window' }) as HTMLAnchorElement;

      expect(link).to.exist();
    });
  });
});
