import { Component } from 'react';
import type { ReactNode } from 'react';
import type { noticeError } from 'newrelic';
import ErrorStatusPage from './error-status-page';

type NewRelicAgent = { noticeError: typeof noticeError };

interface NewRelicGlobals {
  newrelic?: NewRelicAgent;
}

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

  componentDidCatch(error) {
    (globalThis as typeof globalThis & NewRelicGlobals).newrelic?.noticeError(error);
  }

  render() {
    const { children } = this.props;
    const { hasError } = this.state;

    return hasError ? <ErrorStatusPage /> : children;
  }
}

export default ErrorBoundary;
