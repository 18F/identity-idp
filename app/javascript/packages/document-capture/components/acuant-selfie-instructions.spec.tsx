import { render } from '@testing-library/react';
import AcuantSelfieInstructions from './acuant-selfie-instructions';

describe('SelfieInstructions', () => {
  let getByText;
  let queryAllByRole;
  let getByRole;

  beforeEach(() => {
    const renderedComponent = render(new AcuantSelfieInstructions());
    getByText = renderedComponent.getByText;
    getByRole = renderedComponent.getByRole;
    queryAllByRole = renderedComponent.queryAllByRole;
  });

  it('renders the header', () => {
    expect(getByText('How to take your photo')).to.exist();
  });

  it('renders the instruction graphics', () => {
    expect(queryAllByRole('img').length).to.equal(2);
  });

  it('renders the first instruction block', () => {
    expect(
      getByText(
        'Line up your face with the green circle. Hold still and wait for the tool to capture a photo.',
      ),
    ).to.exist();
  });

  it('renders the second instruction block', () => {
    expect(
      getByText(
        'After your photo is automatically captured, tap the green checkmark to accept the photo.',
      ),
    ).to.exist();
  });
});
