import { render } from '@testing-library/react';
import type { ComponentType } from 'react';
import { Provider as MarketingSiteContextProvider } from '../context/marketing-site';
import InPersonPrepareStep from './in-person-prepare-step';

describe('InPersonPrepareStep', () => {
  const DEFAULT_PROPS = { toPreviousStep() {}, value: {} };

  it('renders a privacy disclaimer', () => {
    const { getByText, queryByRole } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />);

    expect(getByText('in_person_proofing.body.prepare.privacy_disclaimer')).to.exist();
    expect(
      queryByRole('link', {
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_tab',
      }),
    ).not.to.exist();
  });

  context('with marketing site context URL', () => {
    const securityAndPrivacyHowItWorksURL = 'http://example.com/security-and-privacy-how-it-works';
    const wrapper: ComponentType = ({ children }) => (
      <MarketingSiteContextProvider
        helpCenterRedirectURL="http://example.com/redirect/"
        securityAndPrivacyHowItWorksURL={securityAndPrivacyHowItWorksURL}
      >
        {children}
      </MarketingSiteContextProvider>
    );

    it('renders a privacy disclaimer link', () => {
      const { getByRole } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />, { wrapper });

      const link = getByRole('link', {
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_tab',
      }) as HTMLAnchorElement;

      expect(link.href).to.equal(securityAndPrivacyHowItWorksURL);
    });
  });
});
