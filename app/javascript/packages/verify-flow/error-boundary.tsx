import { Component } from 'react';
import type { ReactNode } from 'react';
import { trackError } from '@18f/identity-analytics';
import ErrorStatusPage from './error-status-page';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props) {
    super(props);

    this.state = { hasError: false };
  }

  static getDerivedStateFromError = () => ({ hasError: true });

  componentDidCatch(error: Error) {
    trackError(error);
  }

  render() {
    const { children } = this.props;
    const { hasError } = this.state;

    return hasError ? <ErrorStatusPage /> : children;
  }
}

export default ErrorBoundary;
