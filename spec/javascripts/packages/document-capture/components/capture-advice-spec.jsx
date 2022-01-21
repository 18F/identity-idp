import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import { AnalyticsContext } from '@18f/identity-document-capture';
import CaptureAdvice from '@18f/identity-document-capture/components/capture-advice';
import { render } from '../../../support/document-capture';

describe('document-capture/components/capture-advice', () => {
  it('logs warning events', () => {
    const addPageAction = sinon.spy();

    const { getByRole } = render(
      <AnalyticsContext.Provider value={{ addPageAction }}>
        <CaptureAdvice onTryAgain={() => {}} />
      </AnalyticsContext.Provider>,
    );

    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: warning shown',
      payload: {
        location: 'doc_auth_capture_advice',
        remaining_attempts: undefined,
      },
    });

    const button = getByRole('button');
    userEvent.click(button);

    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: warning action triggered',
      payload: {
        location: 'doc_auth_capture_advice',
      },
    });
  });
});
