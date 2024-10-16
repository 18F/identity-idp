import { DeviceContext, SelfieCaptureContext } from '@18f/identity-document-capture';
import DocumentSideAcuantCapture from '@18f/identity-document-capture/components/document-side-acuant-capture';
import { expect } from 'chai';
import { render } from '../../../support/document-capture';

describe('DocumentSideAcuantCapture', () => {
  const DEFAULT_PROPS = {
    errors: [],
    registerField: () => undefined,
    value: '',
    onChange: () => undefined,
    onError: () => undefined,
    isReviewStep: false,
  };

  context('when selfie is _not_ enabled', () => {
    context('and using mobile', () => {
      context('and doc_auth_selfie_desktop_test_mode is false', () => {
        it('_does_ display a photo upload button', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: true }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: false,
                  isSelfieDesktopTestMode: false,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
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

      context('and doc_auth_selfie_desktop_test_mode is true', () => {
        it('_does_ display a photo upload button', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: true }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: false,
                  isSelfieDesktopTestMode: true,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
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
    });

    context('and using desktop', () => {
      context('and doc_auth_selfie_desktop_test_mode is false', () => {
        it('shows a file pick area for each field', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: false }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: false,
                  isSelfieDesktopTestMode: false,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
              </SelfieCaptureContext.Provider>
            </DeviceContext.Provider>,
          );

          const uploadPictureText = queryAllByText('doc_auth.forms.choose_file_html');
          expect(uploadPictureText).to.have.lengthOf(2);
        });
      });

      context('and doc_auth_selfie_desktop_test_mode is true', () => {
        it('shows a file pick area for each field', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: false }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: false,
                  isSelfieDesktopTestMode: true,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
              </SelfieCaptureContext.Provider>
            </DeviceContext.Provider>,
          );

          const uploadPictureText = queryAllByText('doc_auth.forms.choose_file_html');
          expect(uploadPictureText).to.have.lengthOf(2);
        });
      });
    });
  });

  context('when selfie _is_ enabled', () => {
    context('and using mobile', () => {
      context('and doc_auth_selfie_desktop_test_mode is false', () => {
        it('does _not_ display a photo upload button', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: true }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: true,
                  isSelfieDesktopTestMode: false,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="selfie" />
              </SelfieCaptureContext.Provider>
            </DeviceContext.Provider>,
          );

          const takePictureText = queryAllByText('doc_auth.buttons.take_picture');
          expect(takePictureText).to.have.lengthOf(3);

          const takeOrUploadPictureText = queryAllByText(
            'doc_auth.buttons.take_or_upload_picture_html',
          );
          expect(takeOrUploadPictureText).to.have.lengthOf(0);
        });
      });

      context('and doc_auth_selfie_desktop_test_mode is true', () => {
        it('does _not_ display a photo upload button', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: true }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: true,
                  isSelfieDesktopTestMode: true,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="selfie" />
              </SelfieCaptureContext.Provider>
            </DeviceContext.Provider>,
          );

          const takePictureText = queryAllByText('doc_auth.buttons.take_picture');
          expect(takePictureText).to.have.lengthOf(3);

          const takeOrUploadPictureText = queryAllByText(
            'doc_auth.buttons.take_or_upload_picture_html',
          );
          expect(takeOrUploadPictureText).to.have.lengthOf(3);
        });
      });
    });

    context('and using desktop', () => {
      context('and doc_auth_selfie_desktop_test_mode is false', () => {
        it('never loads these components', () => {
          // noop
        });
      });

      context('and doc_auth_selfie_desktop_test_mode is true', () => {
        it('shows a file pick area for each field', () => {
          const { queryAllByText } = render(
            <DeviceContext.Provider value={{ isMobile: false }}>
              <SelfieCaptureContext.Provider
                value={{
                  isSelfieCaptureEnabled: true,
                  isSelfieDesktopTestMode: true,
                  docAuthSeparatePagesEnabled: false,
                }}
              >
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="front" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="back" />
                <DocumentSideAcuantCapture {...DEFAULT_PROPS} side="selfie" />
              </SelfieCaptureContext.Provider>
            </DeviceContext.Provider>,
          );

          const uploadPictureText = queryAllByText('doc_auth.forms.choose_file_html');
          expect(uploadPictureText).to.have.lengthOf(3);
        });
      });
    });
  });
});
