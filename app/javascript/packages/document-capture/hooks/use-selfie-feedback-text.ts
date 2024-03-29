import { useState } from 'react';

/**
 * Allows the Acuant PassiveLiveness code to change the selfie feedback text to prompt the user
 * what they need to change. Text that might show includes: face_not_found: 'Face too small'
 */
function useSelfieFeedbackText() {
  const [selfieFeedbackText, setSelfieFeedbackText] = useState('');
  return { selfieFeedbackText, setSelfieFeedbackText };
}

export default useSelfieFeedbackText;
