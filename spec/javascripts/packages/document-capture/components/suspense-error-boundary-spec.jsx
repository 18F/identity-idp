import React, { lazy } from 'react';
import SuspenseErrorBoundary from '@18f/identity-document-capture/components/suspense-error-boundary';
import render from '../../../support/render';

describe('document-capture/components/suspense-error-boundary', () => {
  it('renders its children', () => {
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

  it('returns errorFallback rendered component with error prop if an error is caught', async () => {
    const Child = () => {
      throw new Error('Ouch!');
    };

    const { findByText } = render(
      <SuspenseErrorBoundary fallback="Loading" errorFallback={({ error }) => error.message}>
        <Child />
      </SuspenseErrorBoundary>,
    );

    expect(await findByText('Ouch!')).to.be.ok();
    expect(console).to.have.loggedError();
  });
});
