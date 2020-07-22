const DOC_CAPTURE_TIMEOUT = 1000 * 60 * 25; // 25 minutes
const DOC_CAPTURE_POLL_INTERVAL = 5000;
const MAX_DOC_CAPTURE_POLL_ATTEMPTS = Math.floor(
  DOC_CAPTURE_TIMEOUT / DOC_CAPTURE_POLL_INTERVAL,
);

const docCaptureContinueButtonForm = () =>
  document.querySelector('.doc_capture_continue_button_form');

const docCaptureContinueInstructions = () =>
  document.querySelector('#doc_capture_continue_instructions');

const handleMaxPollAttempts = () => {
  // Unhide the continue buttons so the user can continue manually
  docCaptureContinueButtonForm().style = 'display:default;';
  docCaptureContinueInstructions().style = 'display:default;';
};

const docCaptureComplete = () => {
  docCaptureContinueButtonForm().submit();
};

const sendDocAuthPollRequest = () => {
  const request = new XMLHttpRequest();
  request.open('GET', '/verify/doc_auth/link_sent/poll/', true);
  request.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
  request.onload = function () {
    // This endpoint renders a 202 for a pending request
    if (request.status === 200) {
      docCaptureComplete();
    }
  };
  request.send();
};

let totalDocCapturePollAttempts = 0;
const pollForDocCaptureCompletion = () => {
  if (totalDocCapturePollAttempts >= MAX_DOC_CAPTURE_POLL_ATTEMPTS) {
    return handleMaxPollAttempts();
  }
  totalDocCapturePollAttempts += 1;
  return sendDocAuthPollRequest();
};

const startDocCaptureCompletePoll = () => {
  docCaptureContinueButtonForm().style = 'display:none;';
  docCaptureContinueInstructions().style = 'display:none;';
  setInterval(pollForDocCaptureCompletion, DOC_CAPTURE_POLL_INTERVAL);
};

document.addEventListener('DOMContentLoaded', startDocCaptureCompletePoll);
