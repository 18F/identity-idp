import React from 'react';
import { I18nContext, ServiceProviderContext } from '@18f/identity-document-capture';
import MobileIntroStep from '@18f/identity-document-capture/components/mobile-intro-step';
import { render } from '../../../support/document-capture';

describe('document-capture/components/mobile-intro-step', () => {
  context('service provider context', () => {
    it('renders with name and help link', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.no_other_id_help_bold_html':
              '<strong>If you do not have another state-issued ID</strong>, ' +
              '<a href=%{failure_to_proof_url}>get help at %{sp_name}.</a>',
          }}
        >
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
            }}
          >
            <MobileIntroStep />
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>,
      );

      const help = getByText(
        (_content, element) =>
          element.innerHTML ===
          '<strong>If you do not have another state-issued ID</strong>, ' +
            '<a href="https://example.com">get help at Example App.</a>',
      );

      expect(help).to.be.ok();
    });

    it('renders with name', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.no_other_id_help_bold_html':
              '<strong>If you do not have another state-issued ID</strong>, ' +
              '<a href=%{failure_to_proof_url}>get help at %{sp_name}.</a>',
          }}
        >
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: null,
            }}
          >
            <MobileIntroStep />
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>,
      );

      const help = getByText(
        (_content, element) =>
          element.innerHTML ===
          '<strong>If you do not have another state-issued ID</strong>, get help at Example App.',
      );

      expect(help).to.be.ok();
    });
  });
});
