import { DeviceContext, FeatureFlagContext } from '@18f/identity-document-capture';
import DocumentsStep from '@18f/identity-document-capture/components/documents-step';
import { render } from '../../../support/document-capture';

describe('DocumentSideAcuantCapture', () => {
  context('when selfie is _not_ enabled', () => {
    it('_does_ display a photo upload button', () => {
      const { queryAllByText } = render(
        <FeatureFlagContext.Provider value={{ selfieCaptureEnabled: false }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <DocumentsStep />
          </DeviceContext.Provider>
        </FeatureFlagContext.Provider>,
      );

      const takeOrUploadPictureText = queryAllByText(
        'doc_auth.buttons.take_or_upload_picture_html',
      );
      expect(takeOrUploadPictureText).to.have.lengthOf(2);
    });
  });

  context('when selfie _is_ enabled', () => {
    it('does _not_ display a photo upload button', () => {
      const { queryAllByText } = render(
        <FeatureFlagContext.Provider value={{ selfieCaptureEnabled: true }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <DocumentsStep />
          </DeviceContext.Provider>
        </FeatureFlagContext.Provider>,
      );

      const takePictureText = queryAllByText('doc_auth.buttons.take_picture');
      expect(takePictureText).to.have.lengthOf(3);

      const notExpectedText = 'doc_auth.buttons.take_or_upload_picture_html';
      expect(queryAllByText(notExpectedText)).to.be.an('array').that.is.empty;
    });
  });
});
