function isTrackableErrorEvent(event: ErrorEvent): boolean {
  try {
    const { host, pathname } = new URL(event.filename);
    return host === window.location.host && pathname.endsWith('.js');
  } catch {
    return false;
  }
}

export default isTrackableErrorEvent;
