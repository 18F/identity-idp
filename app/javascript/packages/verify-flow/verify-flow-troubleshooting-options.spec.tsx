import { render } from '@testing-library/react';
import VerifyFlowTroubleshootingOptions from './verify-flow-troubleshooting-options';

describe('VerifyFlowTroubleshootingOptions', () => {
  it('renders troubleshooting options', () => {
    const { getByRole, getAllByRole } = render(<VerifyFlowTroubleshootingOptions />);

    const heading = getByRole('heading');
    const options = getAllByRole('link');

    expect(heading.textContent).to.equal('components.troubleshooting_options.default_heading');
    expect(options).to.have.lengthOf(1);
    expect(options[0].getAttribute('href')).to.equal('https://login.gov/contact/');
    expect(options[0].getAttribute('target')).to.equal('_blank');
    expect(options[0].textContent).to.equal(
      'idv.troubleshooting.options.contact_support links.new_window',
    );
  });
});
