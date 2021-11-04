import StartOverOrCancel from '@18f/identity-document-capture/components/start-over-or-cancel';
import { UploadContextProvider } from '@18f/identity-document-capture';
import { render } from '../../../support/document-capture';

describe('document-capture/components/start-over-or-cancel', () => {
  it('renders start over and cancel links', () => {
    const { getByText } = render(<StartOverOrCancel />);

    expect(getByText('doc_auth.buttons.start_over')).to.be.ok();
    expect(getByText('links.cancel')).to.be.ok();
  });

  it('omits start over link when in hybrid flow', () => {
    const { getByText } = render(
      <UploadContextProvider flowPath="hybrid">
        <StartOverOrCancel />
      </UploadContextProvider>,
    );

    expect(() => getByText('doc_auth.buttons.start_over')).to.throw();
    expect(getByText('links.cancel')).to.be.ok();
  });
});
