import React, { Component, Suspense } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef SuspenseErrorBoundaryProps
 *
 * @prop {ReactNode} fallback      Fallback to show while suspense pending.
 * @prop {ReactNode} errorFallback Fallback to show if suspense resolves as error.
 * @prop {ReactNode} children      Suspense child.
 */

/**
 * @extends {Component<SuspenseErrorBoundaryProps>}
 */
class SuspenseErrorBoundary extends Component {
  constructor(props) {
    super(props);

    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return {
      hasError: true,
    };
  }

  render() {
    const { fallback, errorFallback, children } = this.props;
    const { hasError } = this.state;

    return hasError ? errorFallback : <Suspense fallback={fallback}>{children}</Suspense>;
  }
}

export default SuspenseErrorBoundary;
