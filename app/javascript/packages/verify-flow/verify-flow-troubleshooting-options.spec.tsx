import { render } from '@testing-library/react';
import type { ComponentType } from 'react';
import FlowContext, { FlowContextValue } from './context/flow-context';
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

  context('with in-person proofing option', () => {
    const inPersonURL = 'http://example.com';
    const wrapper: ComponentType = ({ children }) => (
      <FlowContext.Provider value={{ inPersonURL } as FlowContextValue}>
        {children}
      </FlowContext.Provider>
    );

    it('renders additional troubleshooting options', () => {
      it('renders troubleshooting options', () => {
        const { getAllByRole } = render(<VerifyFlowTroubleshootingOptions />, { wrapper });

        const headings = getAllByRole('heading');
        const options = getAllByRole('link');

        expect(headings).to.have.lengthOf(2);
        expect(headings[0].textContent).to.equal(
          'components.troubleshooting_options.default_heading',
        );
        expect(headings[0].textContent).to.equal('idv.troubleshooting.headings.are_you_near');
        expect(options).to.have.lengthOf(2);
        expect(options[0].getAttribute('href')).to.equal('https://login.gov/contact/');
        expect(options[0].getAttribute('target')).to.equal('_blank');
        expect(options[0].textContent).to.equal(
          'idv.troubleshooting.options.contact_support links.new_window',
        );
        expect(options[1].getAttribute('href')).to.equal(inPersonURL);
        expect(options[1].getAttribute('target')).to.equal('');
        expect(options[1].textContent).to.equal('idv.troubleshooting.options.verify_in_person');
      });
    });
  });
});
