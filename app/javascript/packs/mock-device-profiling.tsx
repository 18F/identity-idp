import { render } from 'react-dom';
import { useInstanceId } from '@18f/identity-react-hooks';
import { ChangeEvent } from 'react';

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
    return true;
  });
  return sessionId;
}

function submitMockFraudResult({ result, sessionId }: { result: string; sessionId?: string }) {
  window.fetch('/test/device_profiling', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      session_id: sessionId,
      result,
    }),
  });
}

const CHAOS_OPTIONS: { apply: () => void; undo: () => void }[] = [
  {
    apply: () => {
      document.body.style.transform = 'scale(-1, 1)';
    },
    undo: () => {
      document.body.style.transform = '';
    },
  },
  {
    apply: () => {
      document.body.style.transform = 'rotate(5deg)';
    },
    undo: () => {
      document.body.style.transform = '';
    },
  },
  {
    apply: () => {
      document.body.style.filter = 'invert(100%)';
    },
    undo: () => {
      document.body.style.filter = '';
    },
  },
  {
    apply: () => {
      document.body.style.fontFamily = 'Comic Sans MS';
    },
    undo: () => {
      document.body.style.fontFamily = '';
    },
  },
];

let undoLast: () => void | undefined;

function mockFraudResultSelected(event: ChangeEvent<HTMLSelectElement>) {
  const { value } = event.target;

  if (value === 'chaotic') {
    const randomChaosOption = CHAOS_OPTIONS[Math.floor(Math.random() * CHAOS_OPTIONS.length)];
    randomChaosOption.apply();
    undoLast = randomChaosOption.undo;
  } else {
    undoLast?.();
    submitMockFraudResult({ result: value, sessionId: loadSessionId() });
  }
}

function MockDeviceProfilingOptions() {
  const instanceId = useInstanceId();
  const inputId = `select-input-${instanceId}`;

  return (
    <>
      {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
      <label className="usa-label" htmlFor={inputId}>
        <strong className="text-accent-warm-dark">For sandbox testing only:</strong> Mock device
        profiling behavior
      </label>
      <select
        className="border-05 border-accent-warm-dark"
        onChange={mockFraudResultSelected}
        name="mock_profiling_result"
        id={inputId}
      >
        <option value="no_result">No Result</option>
        <option value="pass">Pass</option>
        <option value="reject">Reject</option>
        <option value="review">Review</option>
        <option value="chaotic">Do something chaotic</option>
      </select>
    </>
  );
}

document.addEventListener('DOMContentLoaded', () => {
  const ssnInput = document.getElementsByName('doc_auth[ssn]')[0];

  if (ssnInput) {
    const passwordToggle = ssnInput.closest('lg-password-toggle');

    const div = document.createElement('div');
    passwordToggle?.parentElement?.appendChild(div);

    render(<MockDeviceProfilingOptions />, div);
  }
});
