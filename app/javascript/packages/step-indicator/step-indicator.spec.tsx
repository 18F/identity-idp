import { render } from '@testing-library/react';
import StepIndicator from './step-indicator';

describe('StepIndicator', () => {
  it('renders as a labelled region', () => {
    const { container, getByRole, getByLabelText } = render(<StepIndicator />);

    const element = container.firstElementChild!;

    expect(element.tagName).to.equal('LG-STEP-INDICATOR');
    expect(getByRole('region')).to.equal(element);
    expect(getByLabelText('step_indicator.accessible_label')).to.equal(element);
  });

  it('applies given class name', () => {
    const { container } = render(<StepIndicator className="my-custom-class" />);

    const element = container.firstElementChild!;

    expect(element.classList.contains('my-custom-class')).to.be.true();
  });

  it('renders children inside scroller list', () => {
    const { getByText } = render(
      <StepIndicator>
        <li>Example</li>
      </StepIndicator>,
    );

    const item = getByText('Example');

    expect(item.parentElement!.classList.contains('step-indicator__scroller')).to.be.true();
  });
});
