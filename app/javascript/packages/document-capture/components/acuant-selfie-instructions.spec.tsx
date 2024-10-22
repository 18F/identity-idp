import { render } from '@testing-library/react';
import AcuantSelfieInstructions from './acuant-selfie-instructions';

describe('SelfieInstructions', () => {
  let getByText;
  let queryAllByRole;

  beforeEach(() => {
    const renderedComponent = render(<AcuantSelfieInstructions />);
    getByText = renderedComponent.getByText;
    queryAllByRole = renderedComponent.queryAllByRole;
  });

  it('renders the header', () => {
    expect(getByText('doc_auth.headings.selfie_instructions.howto')).to.exist();
  });

  it('renders the instruction graphics', () => {
    expect(queryAllByRole('img').length).to.equal(2);
  });

  it('renders the first instruction block', () => {
    expect(getByText('doc_auth.info.selfie_capture_help_1')).to.exist();
  });

  it('renders the second instruction block', () => {
    expect(getByText('doc_auth.info.selfie_capture_help_2')).to.exist();
  });
});
