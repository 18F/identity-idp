import { render } from '@testing-library/react';
import ProcessListItem from './process-list-item';

describe('ProcessListItem', () => {
  it('renders the component with expected class and children', () => {
    const { container } = render(
      <ProcessListItem heading="Example heading">
        <div>Example</div>
      </ProcessListItem>,
    );

    const wrapper = container.firstElementChild!;
    expect(wrapper.classList.contains('usa-process-list__item')).to.be.true();

    const processListHeading = wrapper.firstElementChild!;
    expect(processListHeading.classList.contains('usa-process-list__heading')).to.be.true();
    expect(processListHeading.textContent).to.equal('Example heading');
    const child = processListHeading.nextElementSibling!;
    expect(child.textContent).to.equal('Example');
  });

  it('renders the heading with no class if headingUnstyled is passed', () => {
    const { container } = render(
      <ProcessListItem heading="Example heading" headingUnstyled>
        <div>Example</div>
      </ProcessListItem>,
    );

    const wrapper = container.firstElementChild!;
    const processListHeading = wrapper.firstElementChild!;
    expect(processListHeading.classList).to.be.empty();
  });
});
