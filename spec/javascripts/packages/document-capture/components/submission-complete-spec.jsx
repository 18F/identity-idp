import React from 'react';
import sinon from 'sinon';
import { waitFor } from '@testing-library/dom';
import useAsync from '@18f/identity-document-capture/hooks/use-async';
import SubmissionComplete, {
  RetrySubmissionError,
} from '@18f/identity-document-capture/components/submission-complete';
import SuspenseErrorBoundary from '@18f/identity-document-capture/components/suspense-error-boundary';
import render from '../../../support/render';
import { useCleanDOM } from '../../../support/dom';
import { useSandbox } from '../../../support/sinon';

describe('document-capture/components/submission-complete-step', () => {
  const sandbox = useSandbox();
  useCleanDOM();

  let response = { success: true };

  function TestComponent() {
    const resource = useAsync(() => Promise.resolve(response));
    return <SubmissionComplete resource={resource} />;
  }

  it('renders fallback while loading', () => {
    const { getByText } = render(
      <SuspenseErrorBoundary fallback="Loading...">
        <TestComponent />
      </SuspenseErrorBoundary>,
    );

    expect(getByText('Loading...')).to.be.ok();
  });

  it('submits form once loading is complete', async () => {
    const onSubmit = sinon.mock().callsFake((event) => event.preventDefault());

    const form = document.createElement('form');
    form.className = 'js-document-capture-form';
    form.addEventListener('submit', onSubmit);
    document.body.appendChild(form);

    render(
      <SuspenseErrorBoundary fallback="Loading...">
        <TestComponent />
      </SuspenseErrorBoundary>,
    );

    await waitFor(() => expect(onSubmit.calledOnce).to.be.true());
  });

  it('retries on pending success', async () => {
    const onSubmit = sinon.mock().callsFake((event) => event.preventDefault());
    const onError = sinon.spy();
    sandbox.spy(window, 'setTimeout');

    const form = document.createElement('form');
    form.className = 'js-document-capture-form';
    form.addEventListener('submit', onSubmit);
    document.body.appendChild(form);

    response = { success: true, isPending: true };

    render(
      <SuspenseErrorBoundary fallback={null} onError={onError}>
        <TestComponent />
      </SuspenseErrorBoundary>,
    );

    expect(onError.called).to.be.false();
    await waitFor(() => expect(onError.calledOnce).to.be.true());
    expect(onError.getCall(0).args[0]).to.be.instanceOf(RetrySubmissionError);
    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(/React will try to recreate this component/);
  });
});
