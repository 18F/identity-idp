import sinon from 'sinon';
// import { computeAccessibleName } from 'dom-accessibility-api';
import { render } from '@testing-library/react';
// import userEvent from '@testing-library/user-event';
// import { AnalyticsContextProvider } from '../context/analytics';
import AcuantSelfieInstructions from './acuant-selfie-instructions';

describe('SelfieInstructions', () => {
  let getByText, queryAllByRole, getByRole;

  beforeEach(() => {
    const rendered_component = render(
      new AcuantSelfieInstructions()
    );
    getByText = rendered_component.getByText;
    getByRole = rendered_component.getByRole;
    queryAllByRole = rendered_component.queryAllByRole;
  });

  it('renders the header', () => {
    expect(
      getByText('How to take your photo')
    ).to.exist();
  });

  it('renders the instruction graphics', () => {
    const instructionGraphics = 
      expect(queryAllByRole('img').length).to.equal(2);
  });


  it('renders the first instruction block', () => {
    expect(
      getByText('Line up your face with the green circle. Hold still and wait for the tool to capture a photo.')
    ).to.exist();
  });

  it('renders the second instruction block', () => {
    expect(
      getByText('After your photo is automatically captured, tap the green checkmark to accept the photo.')
    ).to.exist();
  });

  it('renders the take photo button', () => {
    expect(
      getByRole('button', { text: 'How to take your photo' })
    ).to.exist();
  });
});
