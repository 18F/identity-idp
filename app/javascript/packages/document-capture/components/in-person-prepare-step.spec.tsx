import sinon from 'sinon';
import { fireEvent, render, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ComponentType } from 'react';
import { useSandbox } from '@18f/identity-test-helpers';
import { Provider as MarketingSiteContextProvider } from '../context/marketing-site';
import { AnalyticsContextProvider } from '../context/analytics';
import InPersonPrepareStep from './in-person-prepare-step';
import InPersonContext, { InPersonContextProps } from '../context/in-person';

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
      <InPersonContext.Provider value={{ inPersonURL } as InPersonContextProps}>
        {children}
      </InPersonContext.Provider>
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

    context('when clicking in quick succession', () => {
      const { clock } = useSandbox({ useFakeTimers: true });

      it('logs submission only once', async () => {
        const delay = 1000;
        const trackEvent = sinon
          .stub()
          .callsFake(() => new Promise((resolve) => setTimeout(resolve, delay)));
        const { getByRole } = render(
          <AnalyticsContextProvider trackEvent={trackEvent}>
            <InPersonPrepareStep {...DEFAULT_PROPS} />
          </AnalyticsContextProvider>,
          { wrapper },
        );

        const link = getByRole('link', { name: 'forms.buttons.continue' });

        const didFollowLinkOnFirstClick = fireEvent.click(link);
        const didFollowLinkOnSecondClick = fireEvent.click(link);

        clock.tick(delay);

        await waitFor(() => window.location.hash === inPersonURL);

        expect(didFollowLinkOnFirstClick).to.be.false();
        expect(didFollowLinkOnSecondClick).to.be.false();
        expect(trackEvent).to.have.been.calledOnceWith('IdV: prepare submitted');
      });
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
