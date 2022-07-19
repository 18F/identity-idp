import { render } from '@testing-library/react';
import IconList from './icon-list';

describe('IconList', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <IconList>
        <div>Example</div>
      </IconList>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-icon-list')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });
});
