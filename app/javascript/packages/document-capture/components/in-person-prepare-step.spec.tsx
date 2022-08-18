import { render } from '@testing-library/react';
import { MarketingSiteContextProvider } from '../context';
import InPersonPrepareStep from './in-person-prepare-step';

describe('InPersonPrepareStep', () => {
  const DEFAULT_PROPS = { toPreviousStep() {}, value: {} };

  it('renders a privacy disclaimer', () => {
    const { getByText, queryByRole } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />);

    expect(getByText('in_person_proofing.body.prepare.privacy_disclaimer')).to.exist();
    expect(
      queryByRole('link', {
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_window',
      }),
    ).not.to.exist();
  });

  context('with marketing site context URL', () => {
    it('renders a privacy disclaimer link', () => {
      const securityAndPrivacyHowItWorksURL =
        'http://example.com/security-and-privacy-how-it-works';
      const { getByRole } = render(
        <MarketingSiteContextProvider
          helpCenterRedirectURL="http://example.com/redirect/"
          securityAndPrivacyHowItWorksURL={securityAndPrivacyHowItWorksURL}
        >
          <InPersonPrepareStep {...DEFAULT_PROPS} />
        </MarketingSiteContextProvider>,
      );

      const link = getByRole('link', {
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_window',
      }) as HTMLAnchorElement;

      expect(link.href).to.equal(securityAndPrivacyHowItWorksURL);
    });
  });
});
