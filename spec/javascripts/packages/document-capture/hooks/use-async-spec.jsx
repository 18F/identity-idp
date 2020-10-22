import React, { useState } from 'react';
import sinon from 'sinon';
import useAsync from '@18f/identity-document-capture/hooks/use-async';
import SuspenseErrorBoundary from '@18f/identity-document-capture/components/suspense-error-boundary';
import render from '../../../support/render';

describe('document-capture/hooks/use-async', () => {
  function Child({ resource }) {
    resource.read();

    return 'Finished';
  }

  function Parent({ createPromise }) {
    const [error, setError] = useState();
    const resource = useAsync(createPromise);

    return (
      <SuspenseErrorBoundary fallback="Loading" onError={setError} handledError={error}>
        {error ? 'Error' : <Child resource={resource} />}
      </SuspenseErrorBoundary>
    );
  }

  it('returns suspense resource that renders fallback', async () => {
    let resolve;
    const createPromise = sinon
      .stub()
      .onCall(0)
      .returns(
        new Promise((_resolve) => {
          resolve = () => {
            _resolve();
          };
        }),
      )
      .onCall(1)
      .throws();

    const { container, findByText } = render(<Parent createPromise={createPromise} />);

    expect(container.textContent).to.equal('Loading');

    resolve();

    expect(await findByText('Finished')).to.be.ok();
  });

  it('returns suspense resource that renders error fallback', async () => {
    let reject;
    const createPromise = sinon
      .stub()
      .onCall(0)
      .returns(
        new Promise((_resolve, _reject) => {
          reject = () => {
            _reject();
          };
        }),
      )
      .onCall(1)
      .throws();

    const { container, findByText } = render(<Parent createPromise={createPromise} />);

    expect(container.textContent).to.equal('Loading');

    reject();

    expect(await findByText('Error')).to.be.ok();
    expect(console).to.have.loggedError();
  });
});
