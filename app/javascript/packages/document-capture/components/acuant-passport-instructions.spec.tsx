import { render } from '@testing-library/react';
import AcuantPassportInstructions from './acuant-passport-instructions';

describe('AcuantPassportInstructions', () => {
  let getByText;
  let queryAllByRole;

  beforeEach(() => {
    const renderedComponent = render(<AcuantPassportInstructions />);
    getByText = renderedComponent.getByText;
    queryAllByRole = renderedComponent.queryAllByRole;
  });

  it('renders the header', () => {
    expect(getByText('doc_auth.headings.passport_instructions.howto')).to.exist();
  });

  it('renders the instruction graphics', () => {
    expect(queryAllByRole('img').length).to.equal(1);
  });

  it('renders the first instruction block', () => {
    expect(getByText('doc_auth.info.passport_capture_help_1')).to.exist();
  });

  it('renders the second instruction block', () => {
    expect(getByText('doc_auth.info.passport_capture_help_2')).to.exist();
  });
});
