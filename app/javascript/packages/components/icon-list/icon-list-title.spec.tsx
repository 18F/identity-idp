import { render } from '@testing-library/react';
import IconListTitle from './icon-list-title';

describe('IconListTitle', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <IconListTitle>
        <div>Example</div>
      </IconListTitle>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-icon-list__title')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });
});
