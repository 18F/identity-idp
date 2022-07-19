import { render } from '@testing-library/react';
import ProcessListHeading from './process-list-heading';

describe('ProcessListHeading', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <ProcessListHeading>
        <li>Example</li>
      </ProcessListHeading>,
    );

    const child = getByText('Example');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-process-list__heading')).to.be.true();
    expect(item.textContent).to.equal('Example');
  });

  it('renders the component with no class if unstyled is passed', () => {
    const { container } = render(
      <ProcessListHeading unstyled>
        <li>Example</li>
      </ProcessListHeading>,
    );

    const item = container.firstElementChild!;

    expect(item.classList).to.be.empty();
  });
});
