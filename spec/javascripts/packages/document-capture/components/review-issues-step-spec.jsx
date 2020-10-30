import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { I18nContext, ServiceProviderContext } from '@18f/identity-document-capture';
import ReviewIssuesStep from '@18f/identity-document-capture/components/review-issues-step';
import { render } from '../../../support/document-capture';

describe('document-capture/components/review-issues-step', () => {
  it('renders with front, back, and selfie inputs', () => {
    const { getByLabelText } = render(<ReviewIssuesStep />);

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
  });

  it('calls onChange callback with uploaded image', () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<ReviewIssuesStep onChange={onChange} />);
    const file = new window.File([''], 'upload.png', { type: 'image/png' });

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);
    expect(onChange.getCall(0).args[0]).to.deep.equal({ front: file });
  });

  context('service provider context', () => {
    it('renders with name and help link', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.no_other_id_help_bold_html':
              'If you do not have another state-issued ID, ' +
              '<a href=%{failure_to_proof_url}>get help at %{sp_name}.</a>',
          }}
        >
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>,
      );

      const help = getByText(
        (_content, element) =>
          element.innerHTML ===
          'If you do not have another state-issued ID, ' +
            '<a href="https://example.com">get help at Example App.</a>',
      );

      expect(help).to.be.ok();
    });

    it('renders with name', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.no_other_id_help_bold_html':
              'If you do not have another state-issued ID, ' +
              '<a href=%{failure_to_proof_url}>get help at %{sp_name}.</a>',
          }}
        >
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: null,
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>,
      );

      const help = getByText(
        (_content, element) =>
          element.innerHTML ===
          'If you do not have another state-issued ID, get help at Example App.',
      );

      expect(help).to.be.ok();
    });

    context('ial2', () => {
      it('renders with front and back inputs', () => {
        const { getByLabelText } = render(
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContext.Provider>,
        );

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(() => getByLabelText('doc_auth.headings.document_capture_selfie')).to.throw();
      });
    });

    context('ial2 strict', () => {
      it('renders with front, back, and selfie inputs', () => {
        const { getByLabelText } = render(
          <ServiceProviderContext.Provider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: true,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContext.Provider>,
        );

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
      });
    });
  });
});
