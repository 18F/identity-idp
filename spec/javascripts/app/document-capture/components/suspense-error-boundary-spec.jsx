import React, { lazy } from 'react';
import render from '../../../support/render';
import SuspenseErrorBoundary from '../../../../../app/javascript/app/document-capture/components/suspense-error-boundary';

describe('document-capture/components/suspense-error-boundary', () => {
  it('renders its children', async () => {
    const { container } = render(
      <SuspenseErrorBoundary fallback="Loading" errorFallback="Error">
        No error
      </SuspenseErrorBoundary>,
    );

    expect(container.textContent).to.equal('No error');
  });

  it('renders fallback prop if suspense pending', async () => {
    const Child = lazy(() => Promise.resolve({ default: () => 'Done' }));

    const { container, findByText } = render(
      <SuspenseErrorBoundary fallback="Loading" errorFallback="Error">
        <Child />
      </SuspenseErrorBoundary>,
    );

    expect(container.textContent).to.equal('Loading');
    expect(await findByText('Done')).to.be.ok();
  });

  it('returns errorFallback prop if an error is caught', async () => {
    const Child = () => {
      throw new Error();
    };

    const { findByText } = render(
      <SuspenseErrorBoundary fallback="Loading" errorFallback="Error">
        <Child />
      </SuspenseErrorBoundary>,
    );

    expect(await findByText('Error')).to.be.ok();
    expect(console).to.have.loggedError();
  });
});
