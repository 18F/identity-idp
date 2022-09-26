import { render } from 'react-dom';
import { useInstanceId } from '@18f/identity-react-hooks';
import { ChangeEvent, useState, useEffect } from 'react';

const { currentScript } = document;

function loadSessionId(): string | undefined {
  if (currentScript instanceof HTMLScriptElement) {
    return new URL(currentScript.src).searchParams.get('session_id') || undefined;
  }
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

interface ChaosOption {
  apply: () => void;
  undo: () => void;
}

const CHAOS_OPTIONS: ChaosOption[] = [
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

function MockDeviceProfilingOptions() {
  const [selectedValue, setSelectedValue] = useState('');

  useEffect(() => {
    if (selectedValue === 'chaotic') {
      const randomChaosOption = CHAOS_OPTIONS[Math.floor(Math.random() * CHAOS_OPTIONS.length)];
      randomChaosOption.apply();
      return randomChaosOption.undo;
    } else if (selectedValue) {
      submitMockFraudResult({ result: selectedValue, sessionId: loadSessionId() });
    }
  }, [selectedValue]);

  const instanceId = useInstanceId();
  const inputId = `select-input-${instanceId}`;

  const options = [
    { value: 'no_result', title: 'No Result' },
    { value: 'pass', title: 'Pass' },
    { value: 'reject', title: 'Reject' },
    { value: 'review', title: 'Review' },
    { value: 'chaotic', title: 'Do something chaotic' },
  ];

  return (
    <>
      {/* eslint-disable-next-line jsx-a11y/label-has-associated-control */}
      <label className="usa-label" htmlFor={inputId}>
        <strong className="text-accent-warm-dark">For sandbox testing only:</strong> Mock device
        profiling behavior
      </label>
      <select
        className="border-05 border-accent-warm-dark"
        onChange={(event: ChangeEvent<HTMLSelectElement>) => {
          const targetValue = event.target.value;
          setSelectedValue(targetValue);
        }}
        name="mock_profiling_result"
        id={inputId}
        defaultValue={selectedValue}
      >
        {options.map(({ value, title }) => (
          <option value={value} key={value}>
            {title}
          </option>
        ))}
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
