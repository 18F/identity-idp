import { Component, Suspense } from 'react';
import type { ReactNode } from 'react';

interface SuspenseErrorBoundaryProps {
  /**
   * Fallback to show while suspense pending.
   */
  fallback: NonNullable<ReactNode> | null;
  /**
   * Error callback.
   */
  onError: (error: Error) => void;
  /**
   * Error instance caught to allow for acknowledgment of rerender, in order to prevent infinite rerendering.
   */
  handledError?: Error;
  /**
   * Suspense child.
   */
  children: ReactNode;
}

interface SuspenseErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

class SuspenseErrorBoundary extends Component<
  SuspenseErrorBoundaryProps,
  SuspenseErrorBoundaryState
> {
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
