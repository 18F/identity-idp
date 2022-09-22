console.log('AAAAA');

/**
 * Loads the ?session_id=SESSION_ID param from the <script> tag. Unfortunately
 * import.meta.url doesn't have live URL params so we need to scrape the DOM.
 */
function loadSessionId(): string | undefined {
  let sessionId;
  Array.from(document.scripts).every((scriptTag) => {
    if (scriptTag.src.includes('session_id')) {
      sessionId = new URL(scriptTag.src).searchParams.get('session_id');
      return false;
    }
  });
  return sessionId;
}

const sessionId = loadSessionId();

console.log(sessionId);
