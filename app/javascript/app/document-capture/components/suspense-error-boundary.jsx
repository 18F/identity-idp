import React, { Component, Suspense } from 'react';
import PropTypes from 'prop-types';

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

SuspenseErrorBoundary.propTypes = {
  fallback: PropTypes.node.isRequired,
  errorFallback: PropTypes.node.isRequired,
  children: PropTypes.node.isRequired,
};

export default SuspenseErrorBoundary;
