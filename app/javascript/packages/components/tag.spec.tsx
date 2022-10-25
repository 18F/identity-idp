import { render } from '@testing-library/react';
import Tag from './tag';

describe('Tag', () => {
  it('renders a tag element with children', () => {
    const { getByText } = render(<Tag>Recommended</Tag>);

    const tag = getByText('Recommended');

    expect(tag.classList.contains('usa-tag')).to.be.true();
  });

  it('renders with additional HTML attribute props', () => {
    const { getByText } = render(
      <Tag id="recommended-tag" className="example">
        Recommended
      </Tag>,
    );

    const tag = getByText('Recommended');

    expect(tag.id).to.equal('recommended-tag');
    expect(tag.classList.contains('usa-tag')).to.be.true();
    expect(tag.classList.contains('example')).to.be.true();
  });
});
