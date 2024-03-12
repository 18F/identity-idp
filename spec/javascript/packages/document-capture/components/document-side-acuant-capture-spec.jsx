import { DeviceContext, SelfieCaptureContext } from '@18f/identity-document-capture';
import DocumentSideAcuantCapture from '@18f/identity-document-capture/components/document-side-acuant-capture';
import { render } from '../../../support/document-capture';

describe('DocumentSideAcuantCapture', () => {
  const DEFAULT_PROPS = {
    errors: [],
    registerField: () => undefined,
  };

  context('when selfie is _not_ enabled', () => {
    it('_does_ display a photo upload button', () => {
      const { queryAllByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <SelfieCaptureContext.Provider value={{ isSelfieCaptureEnabled: false }}>
            <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
            <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
          </SelfieCaptureContext.Provider>
        </DeviceContext.Provider>,
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
        <SelfieCaptureContext.Provider value={{ isSelfieCaptureEnabled: true }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
            <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
            <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="selfie" />
          </DeviceContext.Provider>
        </SelfieCaptureContext.Provider>,
      );

      const takePictureText = queryAllByText('doc_auth.buttons.take_picture');
      expect(takePictureText).to.have.lengthOf(3);

      const notExpectedText = 'doc_auth.buttons.take_or_upload_picture_html';
      expect(queryAllByText(notExpectedText)).to.be.an('array').that.is.empty;
    });
  });
});
