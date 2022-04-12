import sinon from 'sinon';
import { useContext } from 'react';
import userEvent from '@testing-library/user-event';
import {
  AnalyticsContext,
  FailedCaptureAttemptsContext,
  FailedCaptureAttemptsContextProvider,
} from '@18f/identity-document-capture';
import CaptureTroubleshooting from '@18f/identity-document-capture/components/capture-troubleshooting';
import { FormStepsContext } from '@18f/identity-form-steps';
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

  it('triggers content resets', () => {
    const onPageTransition = sinon.spy();
    function FailButton() {
      return (
        <button
          type="button"
          onClick={useContext(FailedCaptureAttemptsContext).onFailedCaptureAttempt}
        >
          Fail
        </button>
      );
    }
    const { getByRole } = render(
      <FormStepsContext.Provider value={{ onPageTransition }}>
        <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={1}>
          <CaptureTroubleshooting>
            <FailButton />
          </CaptureTroubleshooting>
        </FailedCaptureAttemptsContextProvider>
      </FormStepsContext.Provider>,
    );

    expect(onPageTransition).not.to.have.been.called();

    const failButton = getByRole('button', { name: 'Fail' });
    userEvent.click(failButton);
    expect(onPageTransition).to.have.been.calledOnce();

    const tryAgainButton = getByRole('button', { name: 'idv.failure.button.warning' });
    userEvent.click(tryAgainButton);
    expect(onPageTransition).to.have.been.calledTwice();
  });

  it('logs events', () => {
    const addPageAction = sinon.spy();
    const { getByRole } = render(
      <AnalyticsContext.Provider value={{ addPageAction }}>
        <FailedCaptureAttemptsContextProvider maxFailedAttemptsBeforeTips={0}>
          <CaptureTroubleshooting>Default children</CaptureTroubleshooting>
        </FailedCaptureAttemptsContextProvider>
      </AnalyticsContext.Provider>,
    );

    expect(addPageAction).to.have.been.calledTwice();
    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: Capture troubleshooting shown',
      payload: { isAssessedAsGlare: false, isAssessedAsBlurry: false },
    });

    const tryAgainButton = getByRole('button', { name: 'idv.failure.button.warning' });
    userEvent.click(tryAgainButton);

    expect(addPageAction.callCount).to.equal(4);
    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: Capture troubleshooting dismissed',
    });
  });
});
