import { DeviceContext } from '@18f/identity-document-capture';
import DesktopDocumentDisclosure from '@18f/identity-document-capture/components/desktop-document-disclosure';
import { render } from '../../../support/document-capture';

describe('document-capture/components/desktop-document-disclosure', () => {
  context('mobile', () => {
    it('renders nothing', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <DesktopDocumentDisclosure />
        </DeviceContext.Provider>,
      );

      expect(() => getByText('doc_auth.info.document_capture_upload_image')).to.throw();
    });
  });

  context('desktop', () => {
    it('renders disclosure text', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <DesktopDocumentDisclosure />
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.info.document_capture_upload_image')).to.be.ok();
    });
  });
});
