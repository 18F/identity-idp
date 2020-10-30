import sinon from 'sinon';
import { waitFor } from '@testing-library/dom';
import useAsync from '@18f/identity-document-capture/hooks/use-async';
import { UploadContextProvider } from '@18f/identity-document-capture';
import SubmissionComplete, {
  RetrySubmissionError,
} from '@18f/identity-document-capture/components/submission-complete';
import SuspenseErrorBoundary from '@18f/identity-document-capture/components/suspense-error-boundary';
import { render, useDocumentCaptureForm } from '../../../support/document-capture';

describe('document-capture/components/submission-complete-step', () => {
  const onSubmit = useDocumentCaptureForm();

  let response;

  function TestComponent() {
    const resource = useAsync(() => Promise.resolve(response));
    return <SubmissionComplete resource={resource} />;
  }

  beforeEach(() => {
    response = { success: true };
  });

  it('renders fallback while loading', () => {
    const { getByText } = render(
      <SuspenseErrorBoundary fallback="Loading...">
        <TestComponent />
      </SuspenseErrorBoundary>,
    );

    expect(getByText('Loading...')).to.be.ok();
  });

  it('submits form once loading is complete', async () => {
    render(
      <SuspenseErrorBoundary fallback="Loading...">
        <TestComponent />
      </SuspenseErrorBoundary>,
    );

    await waitFor(() => expect(onSubmit.calledOnce).to.be.true());
  });

  it('retries on pending success as configured by upload context poll interval', async () => {
    const onError = sinon.spy();
    response = { success: true, isPending: true };

    const { findByText } = render(
      <UploadContextProvider statusPollInterval={0}>
        <SuspenseErrorBoundary fallback={null} onError={onError}>
          <TestComponent />
        </SuspenseErrorBoundary>
      </UploadContextProvider>,
    );

    expect(onError.called).to.be.false();
    await findByText('doc_auth.headings.interstitial');
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(onError.calledOnce).to.be.true();
    expect(onError.getCall(0).args[0]).to.be.instanceOf(RetrySubmissionError);
    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(/React will try to recreate this component/);
  });

  it('does not retry on pending success if poll interval is not configured', async () => {
    const onError = sinon.spy();

    const { findByText } = render(
      <UploadContextProvider>
        <SuspenseErrorBoundary fallback={null} onError={onError}>
          <TestComponent />
        </SuspenseErrorBoundary>
      </UploadContextProvider>,
    );

    expect(onError.called).to.be.false();
    await findByText('doc_auth.headings.interstitial');
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(onError.called).to.be.false();
  });
});
