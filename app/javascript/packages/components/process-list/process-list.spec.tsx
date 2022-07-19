import { render } from '@testing-library/react';
import ProcessList from './process-list';

describe('ProcessList', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <ProcessList className="example-class">
        <li>Example</li>
      </ProcessList>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-process-list')).to.be.true();
    expect(item.classList.contains('example-class')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });
});
