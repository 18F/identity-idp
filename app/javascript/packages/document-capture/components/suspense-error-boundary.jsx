import React, { Component, Suspense } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('react').FunctionComponent} FunctionComponent */

/**
 * @typedef SuspenseErrorBoundaryProps
 *
 * @prop {NonNullable<ReactNode>|null} fallback Fallback to show while suspense pending.
 * @prop {(error: Error)=>void} onError Error callback.
 * @prop {Error=} handledError Error instance caught to allow for acknowledgment of rerender, in
 * order to prevent infinite rerendering.
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

  componentDidCatch(error) {
    const { onError } = this.props;
    onError(error);
  }

  render() {
    const { fallback, children, handledError } = this.props;
    const { hasError, error } = this.state;

    if (hasError && error !== handledError) {
      return null;
    }

    return <Suspense fallback={fallback}>{children}</Suspense>;
  }
}

export default SuspenseErrorBoundary;
