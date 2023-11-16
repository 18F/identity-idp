import sinon from 'sinon';

import { FlowContext } from '@18f/identity-verify-flow';
import { I18nContext } from '@18f/identity-react-i18n';
import { I18n } from '@18f/identity-i18n';
import userEvent from '@testing-library/user-event';
import type { Navigate } from '@18f/identity-url';
import {
  AnalyticsContextProvider,
  ServiceProviderContextProvider,
} from '@18f/identity-document-capture/context';
import DocumentCaptureNotReady from '@18f/identity-document-capture/components/document-capture-not-ready';
import { expect } from 'chai';
import { render } from '../../../support/document-capture';

describe('DocumentCaptureNotReady', () => {
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
      const { getByRole } = render(
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <ServiceProviderContextProvider
            value={{
              name: spName,
              failureToProofURL: 'http://example.test/url/to/failure-to-proof',
              getFailureToProofURL: () => '',
            }}
          >
            <FlowContext.Provider
              value={{
                currentStep: 'document_capture',
                accountURL: '/account',
                cancelURL: '',
                exitURL: '',
              }}
            >
              <I18nContext.Provider
                value={
                  new I18n({
                    strings: {
                      'doc_auth.not_ready.header': 'header text',
                      'doc_auth.not_ready.content_sp':
                        'If you exit %{app_name} and return to %{sp_name}.',
                      'doc_auth.not_ready.button_sp': 'Exit %{app_name} and return to %{sp_name}',
                    },
                  })
                }
              >
                <DocumentCaptureNotReady navigate={navigateSpy} />
              </I18nContext.Provider>
            </FlowContext.Provider>
          </ServiceProviderContextProvider>
        </AnalyticsContextProvider>,
      );
      // header
      expect(getByRole('heading', { name: 'header text', level: 2 })).to.be.ok();

      // content and exit link
      const exitLink = getByRole('button', { name: 'Exit Login.gov and return to testSP' });
      expect(exitLink).to.be.ok();
      await userEvent.click(exitLink);
      expect(navigateSpy).to.be.called.calledWithMatch(
        /failure-to-proof\?step=document_capture&location=not_ready/,
      );
      expect(trackEvent).to.be.calledWithMatch(/IdV: docauth not ready link clicked/);
    });
  });

  context('without service provider', () => {
    it('renders, track event and redirect', async () => {
      const { getByRole } = render(
        <AnalyticsContextProvider trackEvent={trackEvent}>
          <ServiceProviderContextProvider
            value={{
              name: null,
              failureToProofURL: 'http://example.test/url/to/failure-to-proof',
              getFailureToProofURL: () => '',
            }}
          >
            <FlowContext.Provider
              value={{
                currentStep: 'document_capture',
                accountURL: '/account',
                cancelURL: '',
                exitURL: '',
              }}
            >
              <I18nContext.Provider
                value={
                  new I18n({
                    strings: {
                      'doc_auth.not_ready.header': 'header text',
                      'doc_auth.not_ready.content_nosp':
                        'If you exit %{app_name} now, you will not have verified your identity.',
                      'doc_auth.not_ready.button_nosp': 'Cancel and return to your profile',
                    },
                  })
                }
              >
                <DocumentCaptureNotReady navigate={navigateSpy} />
              </I18nContext.Provider>
            </FlowContext.Provider>
          </ServiceProviderContextProvider>
        </AnalyticsContextProvider>,
      );
      // header
      expect(getByRole('heading', { name: 'header text', level: 2 })).to.be.ok();

      // content and exit link
      const exitLink = getByRole('button', { name: 'Cancel and return to your profile' });
      expect(exitLink).to.be.ok();
      await userEvent.click(exitLink);
      expect(navigateSpy).to.be.called.calledWithMatch(
        /account\?step=document_capture&location=not_ready/,
      );
      expect(trackEvent).to.be.calledWithMatch(/IdV: docauth not ready link clicked/);
    });
  });
});
