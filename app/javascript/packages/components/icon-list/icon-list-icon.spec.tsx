import { render } from '@testing-library/react';
import IconListIcon from './icon-list-icon';

describe('IconListIcon', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <IconListIcon className="example-class">
        <div>Example</div>
      </IconListIcon>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-icon-list__icon')).to.be.true();
    expect(item.classList.contains('example-class')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });
});
