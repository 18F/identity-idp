import sinon from 'sinon';

import { FlowContext } from '@18f/identity-verify-flow';
import DocumentCaptureAbandon from '@18f/identity-document-capture/components/document-capture-abandon';
import { I18nContext } from '@18f/identity-react-i18n';
import { I18n } from '@18f/identity-i18n';
import userEvent from '@testing-library/user-event';
import type { Navigate } from '@18f/identity-url';
import {
  AnalyticsContextProvider,
  ServiceProviderContextProvider,
} from '@18f/identity-document-capture/context';
import { expect } from 'chai';
import { render } from '../../../support/document-capture';

describe('DocumentCaptureAbandon', () => {
  beforeEach(() => {
    const config = document.createElement('script');
    config.id = 'test-config';
    config.type = 'application/json';
    config.setAttribute('data-config', '');
    config.textContent = JSON.stringify({ appName: 'Login.gov' });
    document.body.append(config);
  });
  const trackEvent = sinon.spy();
  const navigateSpy: Navigate = sinon.spy();
  context('with service provider', () => {
    const spName = 'testSP';
    it('renders, track event and redirect', async () => {
      const { getByRole, getByText } = render(
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <ServiceProviderContextProvider
            value={{
              name: spName,
              failureToProofURL: '',
              getFailureToProofURL: () => '',
            }}
          >
            <FlowContext.Provider
              value={{
                cancelURL: '/cancel',
                exitURL: '/exit',
                currentStep: 'document_capture',
              }}
            >
              <I18nContext.Provider
                value={
                  new I18n({
                    strings: {
                      'doc_auth.exit_survey.header': 'header text',
                      'doc_auth.exit_survey.content_html':
                        'Please <a>exit %{app_name} and contact %{sp_name}</a> to find out what you can do.',
                      'doc_auth.exit_survey.optional.button': 'Submit and exit %{app_name}',
                    },
                  })
                }
              >
                <DocumentCaptureAbandon navigate={navigateSpy} />
              </I18nContext.Provider>
            </FlowContext.Provider>
          </ServiceProviderContextProvider>
        </AnalyticsContextProvider>,
      );
      // header
      expect(getByRole('heading', { name: 'header text', level: 3 })).to.be.ok();

      // content and exit link
      const exitLink = getByRole('link', { name: 'exit Login.gov and contact testSP' });
      expect(exitLink).to.be.ok();
      expect(exitLink.getAttribute('href')).to.contain(
        '/exit?step=document_capture&location=optional_question',
      );

      expect(getByText('doc_auth.exit_survey.optional.tag')).to.be.ok();
      // legend
      expect(getByText('doc_auth.exit_survey.optional.legend')).to.be.ok();
      // checkboxes
      expect(
        getByRole('checkbox', { name: 'doc_auth.exit_survey.optional.id_types.us_passport' }),
      ).to.be.ok();
      expect(
        getByRole('checkbox', { name: 'doc_auth.exit_survey.optional.id_types.resident_card' }),
      ).to.be.ok();
      const militaryId = getByRole('checkbox', {
        name: 'doc_auth.exit_survey.optional.id_types.military_id',
      });
      expect(militaryId).to.be.ok();
      expect(
        getByRole('checkbox', { name: 'doc_auth.exit_survey.optional.id_types.tribal_id' }),
      ).to.be.ok();
      expect(
        getByRole('checkbox', {
          name: 'doc_auth.exit_survey.optional.id_types.voter_registration_card',
        }),
      ).to.be.ok();
      const otherId = getByRole('checkbox', {
        name: 'doc_auth.exit_survey.optional.id_types.other',
      });
      expect(otherId).to.be.ok();

      // legal statement
      expect(getByText('idv.legal_statement.information_collection')).to.be.ok();

      // exit button
      const exitButton = getByRole('button', { name: 'Submit and exit Login.gov' });
      expect(exitButton).to.be.ok();
      expect(exitButton.classList.contains('usa-button--outline')).to.be.true();

      await userEvent.click(otherId);
      await userEvent.click(militaryId);
      await userEvent.click(exitButton);
      expect(navigateSpy).to.be.called.calledWithMatch(
        /exit\?step=document_capture&location=optional_question/,
      );
      expect(trackEvent).to.be.calledWithMatch(/IdV: exit optional questions/, {
        ids: [
          { name: 'us_passport', checked: false },
          { name: 'resident_card', checked: false },
          { name: 'military_id', checked: true },
          { name: 'tribal_id', checked: false },
          { name: 'voter_registration_card', checked: false },
          { name: 'other', checked: true },
        ],
      });
    });
  });

  context('without service provider', () => {
    it('renders, track event and redirect', async () => {
      const { getByRole, getByText } = render(
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <ServiceProviderContextProvider
            value={{ name: null, failureToProofURL: '', getFailureToProofURL: () => '' }}
          >
            <FlowContext.Provider
              value={{
                cancelURL: '/cancel',
                exitURL: '/exit',
                currentStep: 'document_capture',
              }}
            >
              <I18nContext.Provider
                value={
                  new I18n({
                    strings: {
                      'doc_auth.exit_survey.header': 'header text',
                      'doc_auth.exit_survey.content_nosp_html':
                        '<a>Cancel verifying your identity with %{app_name}</a> and you can restart the process whenyou’re ready.',
                      'doc_auth.exit_survey.optional.button': 'Submit and exit %{app_name}',
                    },
                  })
                }
              >
                <DocumentCaptureAbandon navigate={navigateSpy} />
              </I18nContext.Provider>
            </FlowContext.Provider>
          </ServiceProviderContextProvider>
        </AnalyticsContextProvider>,
      );

      expect(
        getByRole('link', { name: 'Cancel verifying your identity with Login.gov' }).getAttribute(
          'href',
        ),
      ).to.contain('/cancel?step=document_capture&location=optional_question');

      expect(getByText('doc_auth.exit_survey.optional.tag')).to.be.ok();

      const usPassport = getByRole('checkbox', {
        name: 'doc_auth.exit_survey.optional.id_types.us_passport',
      });
      expect(usPassport).to.be.ok();
      const otherId = getByRole('checkbox', {
        name: 'doc_auth.exit_survey.optional.id_types.other',
      });
      expect(otherId).to.be.ok();

      const exitButton = getByRole('button', { name: 'Submit and exit Login.gov' });
      expect(exitButton).to.be.ok();

      await userEvent.click(otherId);
      await userEvent.click(usPassport);
      await userEvent.click(exitButton);
      expect(navigateSpy).to.be.called.calledWithMatch(
        /cancel\?step=document_capture&location=optional_question/,
      );
      expect(trackEvent).to.be.calledWithMatch(/IdV: exit optional questions/, {
        ids: [
          { name: 'us_passport', checked: true },
          { name: 'resident_card', checked: false },
          { name: 'military_id', checked: false },
          { name: 'tribal_id', checked: false },
          { name: 'voter_registration_card', checked: false },
          { name: 'other', checked: true },
        ],
      });
    });
  });
});
