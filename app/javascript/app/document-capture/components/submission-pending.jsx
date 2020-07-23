import React from 'react';
import Image from './image';

function SubmissionPending() {
  return (
    <div>
      <Image assetPath="clock.svg" alt="" width="50" height="50" />
      <h2>We are processing your images…</h2>
      <p>This might take up to a minute. We’ll load the next step automatically when it’s done.</p>
      <p>Thanks for your patience!</p>
    </div>
  );
}

export default SubmissionPending;
