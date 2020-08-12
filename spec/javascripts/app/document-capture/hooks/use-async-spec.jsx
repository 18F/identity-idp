import React from 'react';
import sinon from 'sinon';
import render from '../../../support/render';
import useAsync from '../../../../../app/javascript/app/document-capture/hooks/use-async';
import SuspenseErrorBoundary from '../../../../../app/javascript/app/document-capture/components/suspense-error-boundary';

describe('document-capture/hooks/use-async', () => {
  function Child({ resource }) {
    resource.read();

    return 'Finished';
  }

  function Parent({ createPromise }) {
    const resource = useAsync(createPromise);

    return (
      <SuspenseErrorBoundary fallback="Loading" errorFallback="Error">
        <Child resource={resource} />
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
