import { createRef } from 'react';
import { render } from '@testing-library/react';
import PageHeading from './page-heading';

describe('document-capture/components/page-heading', () => {
  it('renders as h1', () => {
    const { getByText } = render(<PageHeading>Title</PageHeading>);

    const heading = getByText('Title');

    expect(heading.nodeName).to.equal('H1');
  });

  it('accepts custom class name', () => {
    const { getByText } = render(<PageHeading className="example">Title</PageHeading>);

    const heading = getByText('Title');

    expect(heading.classList.contains('example')).to.be.true();
  });

  it('forwards ref', () => {
    const ref = createRef<HTMLHeadingElement>();
    render(<PageHeading ref={ref} />);

    expect(ref.current!.nodeName).to.equal('H1');
  });

  it('forwards additional props', () => {
    const { getByText } = render(<PageHeading tabIndex="-1">Title</PageHeading>);

    const heading = getByText('Title');

    expect(heading.getAttribute('tabindex')).to.equal('-1');
  });
});
