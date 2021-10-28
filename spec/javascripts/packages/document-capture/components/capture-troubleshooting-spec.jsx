import userEvent from '@testing-library/user-event';
import { FailedCaptureAttemptsContextProvider } from '@18f/identity-document-capture';
import CaptureTroubleshooting from '@18f/identity-document-capture/components/capture-troubleshooting';
import { render } from '../../../support/document-capture';

describe('document-capture/context/capture-troubleshooting', () => {
  it('shows children by default if not exceeded max failed attempts', () => {
    const { getByText } = render(
      <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={1}>
        <CaptureTroubleshooting>Default children</CaptureTroubleshooting>
      </FailedCaptureAttemptsContextProvider>,
    );

    expect(getByText('Default children')).to.be.ok();
  });

  it('shows capture advice if exceeded max failed attempts', () => {
    const { getByText } = render(
      <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={0}>
        <CaptureTroubleshooting>Default children</CaptureTroubleshooting>
      </FailedCaptureAttemptsContextProvider>,
    );

    expect(() => getByText('Default children')).to.throw();
    expect(getByText('doc_auth.headings.capture_troubleshooting_tips')).to.be.ok();
  });

  it('shows children again after clicking try again', () => {
    const { getByRole, getByText } = render(
      <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={0}>
        <CaptureTroubleshooting>Default children</CaptureTroubleshooting>
      </FailedCaptureAttemptsContextProvider>,
    );

    const tryAgainButton = getByRole('button', { name: 'idv.failure.button.warning' });
    userEvent.click(tryAgainButton);

    expect(getByText('Default children')).to.be.ok();
  });
});
