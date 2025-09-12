import { render } from '@testing-library/react';
import type { ComponentType, ReactNode } from 'react';
import {
  MarketingSiteContextProvider,
  ServiceProviderContextProvider,
} from '@18f/identity-document-capture';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import type { ServiceProviderContextType } from '../context/service-provider';
import InPersonContext, { InPersonContextProps } from '../context/in-person';

describe('DocumentCaptureTroubleshootingOptions', () => {
  const helpCenterRedirectURL = 'https://example.com/redirect/';
  const inPersonURL = 'https://example.com/some/idv/ipp/url';
  const chooseIdTypePath = 'https://example.com/verify/choose_id_type';
  const serviceProviderContext: ServiceProviderContextType = {
    name: 'Example SP',
    failureToProofURL: 'http://example.test/url/to/failure-to-proof',
  };
  const wrappers: Record<string, ComponentType> = {
    MarketingSiteContext: ({ children }: { children?: ReactNode }) => (
      <MarketingSiteContextProvider helpCenterRedirectURL={helpCenterRedirectURL}>
        {children}
      </MarketingSiteContextProvider>
    ),
    helpCenterAndServiceProviderContext: ({ children }) => (
      <MarketingSiteContextProvider helpCenterRedirectURL={helpCenterRedirectURL}>
        <ServiceProviderContextProvider value={serviceProviderContext}>
          {children}
        </ServiceProviderContextProvider>
      </MarketingSiteContextProvider>
    ),
  };

  describe('when InPersonContext is provided with chooseIdTypePath', () => {
    it('renders troubleshooting options with "Use another ID type" option', () => {
      const { getAllByRole } = render(
        <InPersonContext.Provider value={{ chooseIdTypePath } as InPersonContextProps}>
          <DocumentCaptureTroubleshootingOptions />
        </InPersonContext.Provider>,
        {
          wrapper: wrappers.MarketingSiteContext,
        },
      );

      const links = getAllByRole('link') as HTMLAnchorElement[];

      expect(links).to.have.lengthOf(3);

      expect(links[0].textContent).to.equal('idv.troubleshooting.options.use_another_id_type');
      expect(links[0].getAttribute('href')).to.equal(chooseIdTypePath);

      expect(links[1].textContent).to.equal(
        'idv.troubleshooting.options.doc_capture_tipslinks.new_tab',
      );
      expect(links[1].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=document_capture_troubleshooting_options',
      );
      expect(links[1].target).to.equal('_blank');

      expect(links[2].textContent).to.equal(
        'idv.troubleshooting.options.supported_documentslinks.new_tab',
      );
      expect(links[2].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=accepted-identification-documents&location=document_capture_troubleshooting_options',
      );
      expect(links[2].target).to.equal('_blank');
    });
  });

  describe('when InPersonContext is not provided', () => {
    it('renders troubleshooting options', () => {
      const { getAllByRole } = render(<DocumentCaptureTroubleshootingOptions />, {
        wrapper: wrappers.MarketingSiteContext,
      });

      const links = getAllByRole('link') as HTMLAnchorElement[];

      expect(links).to.have.lengthOf(2);
      expect(links[0].textContent).to.equal(
        'idv.troubleshooting.options.doc_capture_tipslinks.new_tab',
      );
      expect(links[0].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=document_capture_troubleshooting_options',
      );
      expect(links[0].target).to.equal('_blank');
      expect(links[1].textContent).to.equal(
        'idv.troubleshooting.options.supported_documentslinks.new_tab',
      );
      expect(links[1].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=accepted-identification-documents&location=document_capture_troubleshooting_options',
      );
      expect(links[1].target).to.equal('_blank');
    });
  });

  context('with heading prop', () => {
    it('shows heading text', () => {
      const { getByRole } = render(
        <DocumentCaptureTroubleshootingOptions heading="custom heading" />,
      );

      expect(getByRole('heading', { name: 'custom heading' })).to.exist();
    });
  });

  context('in person proofing links', () => {
    context('without inPersonURL', () => {
      it('does not render in-person call to action', () => {
        const { queryByRole } = render(<DocumentCaptureTroubleshootingOptions />);

        const section = queryByRole('region', { name: 'in_person_proofing.headings.cta' });

        expect(section).not.to.exist();
      });
    });

    context('with inPersonURL', () => {
      const wrapper: ComponentType = ({ children }) => (
        <InPersonContext.Provider value={{ inPersonURL } as InPersonContextProps}>
          {children}
        </InPersonContext.Provider>
      );

      it('renders in-person call to action', () => {
        const { queryByRole } = render(<DocumentCaptureTroubleshootingOptions />, { wrapper });

        const section = queryByRole('region', { name: 'in_person_proofing.headings.cta' });

        expect(section).to.exist();
      });
    });
  });

  context('with document tips hidden', () => {
    it('renders only the use_another_id_type option', () => {
      const { getAllByRole } = render(
        <InPersonContext.Provider value={{ chooseIdTypePath } as InPersonContextProps}>
          <DocumentCaptureTroubleshootingOptions showDocumentTips={false} />,
        </InPersonContext.Provider>,
      );

      const links = getAllByRole('link') as HTMLAnchorElement[];

      expect(links).to.have.lengthOf(1);
      expect(links[0].textContent).to.equal('idv.troubleshooting.options.use_another_id_type');
    });
  });
});
