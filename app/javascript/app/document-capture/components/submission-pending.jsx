import React, { useEffect } from 'react';
import PropTypes from 'prop-types';
import Image from './image';

function SubmissionPending({ onComplete }) {
  useEffect(() => {
    const timeoutId = setTimeout(onComplete, 2000);
    return () => clearTimeout(timeoutId);
  }, []);

  return (
    <div>
      <Image assetPath="clock.svg" alt="" width="50" height="50" />
      <h2>We are processing your images…</h2>
      <p>This might take up to a minute. We’ll load the next step automatically when it’s done.</p>
      <p>Thanks for your patience!</p>
    </div>
  );
}

SubmissionPending.propTypes = {
  onComplete: PropTypes.func.isRequired,
};

export default SubmissionPending;
