import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ComponentType } from 'react';
import {
  MarketingSiteContextProvider,
  ServiceProviderContextProvider,
} from '@18f/identity-document-capture';
import { FlowContext, FlowContextValue } from '@18f/identity-verify-flow';
import { AnalyticsContextProvider } from '../context/analytics';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import type { ServiceProviderContext } from '../context/service-provider';

describe('DocumentCaptureTroubleshootingOptions', () => {
  const helpCenterRedirectURL = 'https://example.com/redirect/';
  const inPersonURL = 'https://example.com/some/idv/ipp/url';
  const serviceProviderContext: ServiceProviderContext = {
    name: 'Example SP',
    failureToProofURL: 'http://example.test/url/to/failure-to-proof',
    getFailureToProofURL: () => '',
  };
  const wrappers: Record<string, ComponentType> = {
    MarketingSiteContext: ({ children }) => (
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

  it('renders troubleshooting options', () => {
    const { getAllByRole } = render(<DocumentCaptureTroubleshootingOptions />, {
      wrapper: wrappers.MarketingSiteContext,
    });

    const links = getAllByRole('link') as HTMLAnchorElement[];

    expect(links).to.have.lengthOf(2);
    expect(links[0].textContent).to.equal(
      'idv.troubleshooting.options.doc_capture_tips links.new_window',
    );
    expect(links[0].getAttribute('href')).to.equal(
      'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=document_capture_troubleshooting_options',
    );
    expect(links[0].target).to.equal('_blank');
    expect(links[1].textContent).to.equal(
      'idv.troubleshooting.options.supported_documents links.new_window',
    );
    expect(links[1].getAttribute('href')).to.equal(
      'https://example.com/redirect/?category=verify-your-identity&article=accepted-state-issued-identification&location=document_capture_troubleshooting_options',
    );
    expect(links[1].target).to.equal('_blank');
  });

  context('with associated service provider', () => {
    it('renders troubleshooting options', () => {
      const { getAllByRole } = render(<DocumentCaptureTroubleshootingOptions />, {
        wrapper: wrappers.helpCenterAndServiceProviderContext,
      });

      const links = getAllByRole('link') as HTMLAnchorElement[];

      expect(links).to.have.lengthOf(3);
      expect(links[0].textContent).to.equal(
        'idv.troubleshooting.options.doc_capture_tips links.new_window',
      );
      expect(links[0].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=document_capture_troubleshooting_options',
      );
      expect(links[0].target).to.equal('_blank');
      expect(links[1].textContent).to.equal(
        'idv.troubleshooting.options.supported_documents links.new_window',
      );
      expect(links[1].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=accepted-state-issued-identification&location=document_capture_troubleshooting_options',
      );
      expect(links[1].target).to.equal('_blank');
      expect(links[2].textContent).to.equal(
        'idv.troubleshooting.options.get_help_at_sp links.new_window',
      );
      expect(links[2].href).to.equal(
        'http://example.test/url/to/failure-to-proof?location=document_capture_troubleshooting_options',
      );
      expect(links[2].target).to.equal('_blank');
    });

    context('with location prop', () => {
      it('appends location to links', () => {
        const { getAllByRole } = render(
          <DocumentCaptureTroubleshootingOptions location="custom" />,
          {
            wrapper: wrappers.helpCenterAndServiceProviderContext,
          },
        );

        const links = getAllByRole('link') as HTMLAnchorElement[];

        expect(links[0].href).to.equal(
          'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=custom',
        );
        expect(links[1].href).to.equal(
          'https://example.com/redirect/?category=verify-your-identity&article=accepted-state-issued-identification&location=custom',
        );
        expect(links[2].href).to.equal(
          'http://example.test/url/to/failure-to-proof?location=custom',
        );
      });
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
      it('has no IPP information', () => {
        const { queryByText } = render(<DocumentCaptureTroubleshootingOptions />);

        expect(queryByText('components.troubleshooting_options.new_feature')).to.not.exist();
      });

      context('with showAlternativeProofingOptions', () => {
        it('has no IPP information', () => {
          const { queryByText } = render(
            <DocumentCaptureTroubleshootingOptions showAlternativeProofingOptions />,
          );

          expect(queryByText('components.troubleshooting_options.new_feature')).to.not.exist();
        });
      });
    });

    context('with inPersonURL', () => {
      const wrapper: ComponentType = ({ children }) => (
        <FlowContext.Provider value={{ inPersonURL } as FlowContextValue}>
          {children}
        </FlowContext.Provider>
      );

      it('has no IPP information', () => {
        const { queryByText } = render(<DocumentCaptureTroubleshootingOptions />);

        expect(queryByText('components.troubleshooting_options.new_feature')).to.not.exist();
      });

      context('with showAlternativeProofingOptions', () => {
        it('has link to IPP flow', () => {
          const { getByText, getByRole } = render(
            <DocumentCaptureTroubleshootingOptions showAlternativeProofingOptions />,
            {
              wrapper,
            },
          );

          expect(getByText('components.troubleshooting_options.new_feature')).to.exist();

          const link = getByRole('link', { name: 'idv.troubleshooting.options.verify_in_person' });

          expect(link).to.exist();
        });

        it('logs an event when clicking the troubleshooting option', async () => {
          const trackEvent = sinon.stub();
          const { getByRole } = render(
            <AnalyticsContextProvider trackEvent={trackEvent}>
              <DocumentCaptureTroubleshootingOptions showAlternativeProofingOptions />
            </AnalyticsContextProvider>,
            { wrapper },
          );

          const link = getByRole('link', { name: 'idv.troubleshooting.options.verify_in_person' });
          await userEvent.click(link);

          expect(trackEvent).to.have.been.calledWith(
            'IdV: verify in person troubleshooting option clicked',
          );
        });
      });
    });
  });

  context('with document tips hidden', () => {
    it('renders nothing', () => {
      const { container } = render(
        <DocumentCaptureTroubleshootingOptions showDocumentTips={false} />,
      );

      expect(container.innerHTML).to.be.empty();
    });

    context('with associated service provider', () => {
      it('renders troubleshooting options', () => {
        const { getAllByRole } = render(
          <DocumentCaptureTroubleshootingOptions showDocumentTips={false} />,
          {
            wrapper: wrappers.helpCenterAndServiceProviderContext,
          },
        );

        const links = getAllByRole('link') as HTMLAnchorElement[];

        expect(links).to.have.lengthOf(1);
        expect(links[0].getAttribute('href')).to.equal(
          'http://example.test/url/to/failure-to-proof?location=document_capture_troubleshooting_options',
        );
      });
    });
  });
});
