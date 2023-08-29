function isTrackableErrorEvent(event: ErrorEvent): boolean {
  try {
    const { host, protocol } = new URL(event.filename);
    return (
      host === window.location.host ||
      (process.env.NODE_ENV === 'development' && protocol === 'webpack-internal:')
    );
  } catch {
    return false;
  }
}

export default isTrackableErrorEvent;
