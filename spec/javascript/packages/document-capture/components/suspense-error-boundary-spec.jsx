import { lazy, useState } from 'react';
import sinon from 'sinon';
import { waitFor } from '@testing-library/dom';
import SuspenseErrorBoundary from '@18f/identity-document-capture/components/suspense-error-boundary';
import { render } from '../../../support/document-capture';

describe('document-capture/components/suspense-error-boundary', () => {
  it('renders its children', () => {
    const { container } = render(
      <SuspenseErrorBoundary fallback="Loading">No error</SuspenseErrorBoundary>,
    );

    expect(container.textContent).to.equal('No error');
  });

  it('renders fallback prop if suspense pending', async () => {
    const Child = lazy(() => Promise.resolve({ default: () => 'Done' }));

    const { container, findByText } = render(
      <SuspenseErrorBoundary fallback="Loading">
        <Child />
      </SuspenseErrorBoundary>,
    );

    expect(container.textContent).to.equal('Loading');
    expect(await findByText('Done')).to.be.ok();
  });

  it('calls onError prop if an error is caught', async () => {
    const onError = sinon.spy();
    const error = new Error('Ouch!');

    const Child = () => {
      throw error;
    };

    const { container } = render(
      <SuspenseErrorBoundary fallback="Loading" onError={onError}>
        <Child />
      </SuspenseErrorBoundary>,
    );

    await waitFor(() => expect(onError.calledOnce).to.be.true());
    expect(onError.getCall(0).args[0]).to.equal(error);
    expect(container.childNodes).to.be.empty();
    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(/React will try to recreate this component/);
  });

  it('rendered component if thrown error is acknowledged by handledError', async () => {
    const error = new Error('Ouch!');

    const Child = () => {
      throw error;
    };

    function TestComponent() {
      const [handledError, setHandledError] = useState();

      return (
        <SuspenseErrorBoundary
          fallback="Loading"
          onError={setHandledError}
          handledError={handledError}
        >
          {handledError ? 'Handled' : <Child />}
        </SuspenseErrorBoundary>
      );
    }

    const { findByText } = render(<TestComponent />);

    await findByText('Handled');
    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(/React will try to recreate this component/);
  });
});
