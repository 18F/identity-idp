import React from 'react';
import Image from './image';

function SubmissionPending() {
  return (
    <div>
      <Image assetPath="id-card.svg" alt="" width="216" height="116" />
      <h2>We are processing your images…</h2>
      <p>This might take up to a minute. We’ll load the next step automatically when it’s done.</p>
      <p>Thanks for your patience!</p>
    </div>
  );
}

export default SubmissionPending;
