import sinon from 'sinon';
import { render, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ComponentType } from 'react';
import { FlowContext } from '@18f/identity-verify-flow';
import type { FlowContextValue } from '@18f/identity-verify-flow';
import { Provider as MarketingSiteContextProvider } from '../context/marketing-site';
import { AnalyticsContextProvider } from '../context/analytics';
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

  context('with in person URL', () => {
    const inPersonURL = '#in_person';
    const wrapper: ComponentType = ({ children }) => (
      <FlowContext.Provider value={{ inPersonURL } as FlowContextValue}>
        {children}
      </FlowContext.Provider>
    );

    it('logs prepare step submission when clicking continue', async () => {
      const trackEvent = sinon.stub();
      const { getByRole } = render(
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <InPersonPrepareStep {...DEFAULT_PROPS} />
        </AnalyticsContextProvider>,
        { wrapper },
      );

      await userEvent.click(getByRole('link', { name: 'forms.buttons.continue' }));
      await waitFor(() => window.location.hash === inPersonURL);

      expect(trackEvent).to.have.been.calledWith('IdV: prepare submitted');
    });
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
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_window',
      }) as HTMLAnchorElement;

      expect(link.href).to.equal(securityAndPrivacyHowItWorksURL);
    });
  });
});
