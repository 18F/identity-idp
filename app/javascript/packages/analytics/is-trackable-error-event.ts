function isTrackableErrorEvent(event: ErrorEvent): boolean {
  try {
    return new URL(event.filename).host === window.location.host;
  } catch {
    return false;
  }
}

export default isTrackableErrorEvent;
