import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import type { ComponentType } from 'react';
import { Provider as MarketingSiteContextProvider } from '../context/marketing-site';
import InPersonPrepareStep from './in-person-prepare-step';
import { InPersonContext } from '../context';

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

  it('renders all steps to verify your identity at a Post Office', () => {
    const { getByText } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />);

    expect(getByText('in_person_proofing.body.prepare.verify_step_post_office')).to.exist();
    expect(getByText('in_person_proofing.body.prepare.verify_step_enter_pii')).to.exist();
    expect(getByText('in_person_proofing.body.prepare.verify_step_enter_phone')).to.exist();
  });

  it('renders about information', () => {
    const { getByText } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />);

    expect(getByText('in_person_proofing.body.prepare.verify_step_about')).to.exist();
  });

  context('Outage message', () => {
    it('renders a warning when the flag is enabled', () => {
      const { queryByText } = render(
        <InPersonContext.Provider
          value={{
            locationsURL: 'https://localhost:3000/unused',
            inPersonOutageMessageEnabled: true,
            inPersonOutageExpectedUpdateDate: 'January 1, 2024',
            optedInToInPersonProofing: false,
            usStatesTerritories: [],
          }}
        >
          <InPersonPrepareStep {...DEFAULT_PROPS} />
        </InPersonContext.Provider>,
      );
      expect(
        queryByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.title'),
      ).to.exist();
    });
    it('does not render a warning when the flag is disabled', () => {
      const { queryByText } = render(
        <InPersonContext.Provider
          value={{
            locationsURL: 'https://localhost:3000/unused',
            inPersonOutageMessageEnabled: false,
            optedInToInPersonProofing: false,
            usStatesTerritories: [],
          }}
        >
          <InPersonPrepareStep {...DEFAULT_PROPS} />
        </InPersonContext.Provider>,
      );
      expect(
        queryByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.title'),
      ).not.to.exist();
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
        name: 'in_person_proofing.body.prepare.privacy_disclaimer_link links.new_tab',
      }) as HTMLAnchorElement;

      expect(link.href).to.equal(securityAndPrivacyHowItWorksURL);
    });
  });

  context('in the NDS layout', () => {
    const ndsWrapper: ComponentType = ({ children }) => (
      <MarketingSiteContextProvider
        helpCenterRedirectURL="http://example.com/redirect/"
        securityAndPrivacyHowItWorksURL="http://example.com/security-and-privacy-how-it-works"
      >
        <InPersonContext.Provider
          value={{
            locationsURL: 'https://localhost:3000/unused',
            inPersonOutageMessageEnabled: false,
            optedInToInPersonProofing: false,
            usStatesTerritories: [],
            ndsLayout: true,
          }}
        >
          {children}
        </InPersonContext.Provider>
      </MarketingSiteContextProvider>
    );

    it('renders the NDS heading, intro and steps', () => {
      const { getByRole, getByText, container } = render(
        <InPersonPrepareStep {...DEFAULT_PROPS} />,
        { wrapper: ndsWrapper },
      );

      expect(container.querySelector('section.auth.auth--form-page')).to.exist();
      expect(
        getByRole('heading', { level: 1, name: 'in_person_proofing.headings.prepare' }),
      ).to.exist();
      expect(
        getByText('nds.post_office.prepare.intro').classList.contains('auth__intro-description'),
      ).to.be.true();
      expect(container.querySelector('hr.divider')).to.exist();
      const steps = Array.from(container.querySelectorAll('ol.list > li')).map(
        (li) => li.textContent,
      );
      expect(steps).to.deep.equal([
        'in_person_proofing.body.prepare.verify_step_post_office',
        'nds.post_office.prepare.step_details',
        'nds.post_office.prepare.step_phone',
      ]);
    });

    it('omits the legacy extras the NDS frame lacks', () => {
      const { queryByText } = render(<InPersonPrepareStep {...DEFAULT_PROPS} />, {
        wrapper: ndsWrapper,
      });

      expect(queryByText('in_person_proofing.body.prepare.verify_step_about')).not.to.exist();
      expect(queryByText('in_person_proofing.body.prepare.privacy_disclaimer')).not.to.exist();
      expect(queryByText('idv.troubleshooting.options.learn_more_verify_in_person')).not.to.exist();
    });

    it('renders a primary Continue submit button and a tertiary Back link-button', async () => {
      const toPreviousStep = sinon.stub();
      const { getByRole } = render(
        <InPersonPrepareStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
        { wrapper: ndsWrapper },
      );

      const continueButton = getByRole('button', { name: 'forms.buttons.continue' });
      expect(continueButton.getAttribute('type')).to.equal('submit');
      expect(continueButton.classList.contains('usa-button--lg')).to.be.true();

      const back = getByRole('link', { name: 'forms.buttons.back' });
      expect(back.classList.contains('usa-button--tertiary')).to.be.true();
      await userEvent.click(back);
      expect(toPreviousStep).to.have.been.calledOnce();
    });
  });
});
