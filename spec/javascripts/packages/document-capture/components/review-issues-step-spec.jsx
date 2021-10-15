import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  ServiceProviderContextProvider,
  UploadContextProvider,
} from '@18f/identity-document-capture';
import ReviewIssuesStep, {
  reviewIssuesStepValidator,
} from '@18f/identity-document-capture/components/review-issues-step';
import { I18nContext } from '@18f/identity-react-i18n';
import { render } from '../../../support/document-capture';
import { useSandbox } from '../../../support/sinon';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/review-issues-step', () => {
  const sandbox = useSandbox();

  describe('reviewIssuesStepValidator', () => {
    it('returns false if given undefined value', () => {
      const isValid = reviewIssuesStepValidator();

      expect(isValid).to.be.false();
    });

    it('returns false if either of front or back are absent', () => {
      for (const key of ['front', 'back']) {
        const isValid = reviewIssuesStepValidator({ [key]: new window.Blob() });

        expect(isValid).to.be.false();
      }
    });

    it('returns true if front and back are given, and selfie is not applicable', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
      });

      expect(isValid).to.be.true();
    });

    it('returns false if selfie is applicable and missing', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
        selfie: null,
      });

      expect(isValid).to.be.false();
    });

    it('returns true if selfie is applicable and given', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
        selfie: new window.Blob(),
      });

      expect(isValid).to.be.true();
    });
  });

  it('renders with front, back, and selfie inputs', () => {
    const { getByLabelText } = render(<ReviewIssuesStep />);

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(<ReviewIssuesStep onChange={onChange} />);
    const file = await getFixtureFile('doc_auth_images/id-back.jpg');

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);
    await new Promise((resolve) => onChange.callsFake(resolve));
    expect(onChange).to.have.been.calledWith({
      front: file,
      front_image_metadata: sinon.match(/^\{.+\}$/),
    });
  });

  it('performs background encrypted uploads', async () => {
    const onChange = sandbox.stub();
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve({
        ok: true,
        status: 200,
        headers: new window.Headers(),
      }),
    );
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
    const { getByLabelText } = render(
      <UploadContextProvider
        backgroundUploadURLs={{ back: 'about:blank#back' }}
        backgroundUploadEncryptKey={key}
      >
        <ReviewIssuesStep onChange={onChange} />)
      </UploadContextProvider>,
    );

    const file = await getFixtureFile('doc_auth_images/id-back.jpg');

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), file);
    await new Promise((resolve) => onChange.callsFake(resolve));
    const patch = onChange.getCall(0).args[0];
    expect(await patch.back_image_url).to.equal('about:blank#back');
    expect(window.fetch.getCall(0).args[0]).to.equal('about:blank#back');
  });

  context('service provider context', () => {
    it('renders with name and help link', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{
            'doc_auth.info.get_help_at_sp_html':
              '<strong>Having trouble?</strong> Get help at %{sp_name}',
          }}
        >
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com/?step=document_capture',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContextProvider>
        </I18nContext.Provider>,
      );

      const help = getByText('Having trouble?').closest('a');

      expect(help).to.be.ok();
      expect(help.href).to.equal(
        'https://example.com/?step=document_capture&location=review_issues_having_trouble',
      );
    });

    context('ial2', () => {
      it('renders with front and back inputs', () => {
        const { getByLabelText } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContextProvider>,
        );

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(() => getByLabelText('doc_auth.headings.document_capture_selfie')).to.throw();
      });
    });

    context('ial2 strict', () => {
      it('renders with front, back, and selfie inputs', () => {
        const { getByLabelText } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: true,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContextProvider>,
        );

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
      });
    });
  });
});
