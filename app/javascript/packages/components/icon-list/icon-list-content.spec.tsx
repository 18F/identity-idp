import { render } from '@testing-library/react';
import IconListContent from './icon-list-content';

describe('IconListContent', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <IconListContent>
        <div>Example</div>
      </IconListContent>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-icon-list__content')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });
});
