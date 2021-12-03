import { render } from '@testing-library/react';
import { composeComponents } from '@18f/identity-compose-components';
import {
  HelpCenterContextProvider,
  ServiceProviderContextProvider,
} from '@18f/identity-document-capture';
import DocumentCaptureTroubleshootingOptions from '@18f/identity-document-capture/components/document-capture-troubleshooting-options';

describe('DocumentCaptureTroubleshootingOptions', () => {
  function renderWithContext({ serviceProviderContext } = {}) {
    const Component = composeComponents(
      ...[
        [
          HelpCenterContextProvider,
          { value: { helpCenterRedirectURL: 'https://example.com/redirect/' } },
        ],
        serviceProviderContext && [
          ServiceProviderContextProvider,
          { value: serviceProviderContext },
        ],
        [DocumentCaptureTroubleshootingOptions],
      ].filter(Boolean),
    );

    return render(<Component />);
  }

  it('renders troubleshooting options', () => {
    const { getAllByRole } = renderWithContext();

    const links = /** @type {HTMLAnchorElement[]} */ (getAllByRole('link'));

    expect(links).to.have.lengthOf(2);
    expect(links[0].textContent).to.equal(
      'idv.troubleshooting.options.doc_capture_tips links.new_window',
    );
    expect(links[0].getAttribute('href')).to.equal(
      'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=troubleshooting_options',
    );
    expect(links[0].target).to.equal('_blank');
    expect(links[1].textContent).to.equal(
      'idv.troubleshooting.options.supported_documents links.new_window',
    );
    expect(links[1].getAttribute('href')).to.equal(
      'https://example.com/redirect/?category=verify-your-identity&article=accepted-state-issued-identification&location=troubleshooting_options',
    );
    expect(links[1].target).to.equal('_blank');
  });

  context('with associated service provider', () => {
    it('renders troubleshooting options', () => {
      const { getAllByRole } = renderWithContext({
        serviceProviderContext: {
          name: 'Example SP',
          failureToProofURL: 'http://example.test/url/to/failure-to-proof',
        },
      });

      const links = /** @type {HTMLAnchorElement[]} */ (getAllByRole('link'));

      expect(links).to.have.lengthOf(3);
      expect(links[0].textContent).to.equal(
        'idv.troubleshooting.options.doc_capture_tips links.new_window',
      );
      expect(links[0].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=how-to-add-images-of-your-state-issued-id&location=troubleshooting_options',
      );
      expect(links[0].target).to.equal('_blank');
      expect(links[1].textContent).to.equal(
        'idv.troubleshooting.options.supported_documents links.new_window',
      );
      expect(links[1].getAttribute('href')).to.equal(
        'https://example.com/redirect/?category=verify-your-identity&article=accepted-state-issued-identification&location=troubleshooting_options',
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
  });
});
