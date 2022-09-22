console.log('AAAAA');

function loadSessionId(): string | undefined {
  for (let script in document.scripts) {
    if (scriptTag.src.includes('session_id')) {
      return new URL(scriptTag.src).searchParams.get('session_id');
    }
  }
}

const sessionId = loadSessionId();

console.log(sessionId);
