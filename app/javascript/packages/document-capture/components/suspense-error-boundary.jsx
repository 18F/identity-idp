import React, { Component, Suspense, createElement } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('react').FunctionComponent} FunctionComponent */

/**
 * @typedef SuspenseErrorBoundaryProps
 *
 * @prop {NonNullable<ReactNode>|null} fallback Fallback to show while suspense pending.
 * @prop {NonNullable<ReactNode>|FunctionComponent|null} errorFallback Fallback to show if suspense
 * resolves as error.
 * @prop {ReactNode} children Suspense child.
 */

/**
 * @extends {Component<SuspenseErrorBoundaryProps>}
 */
class SuspenseErrorBoundary extends Component {
  constructor(props) {
    super(props);

    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return {
      hasError: true,
      error,
    };
  }

  render() {
    const { fallback, errorFallback, children } = this.props;
    const { hasError, error } = this.state;

    if (hasError) {
      const isErrorFallbackComponent = typeof errorFallback === 'function';
      return isErrorFallbackComponent
        ? createElement(/** @type {FunctionComponent} */ (errorFallback), { error })
        : errorFallback;
    }

    return <Suspense fallback={fallback}>{children}</Suspense>;
  }
}

export default SuspenseErrorBoundary;
