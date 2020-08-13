import PropTypes from 'prop-types';

function SubmissionComplete({ resource }) {
  const response = resource.read();

  return `Finished sending: ${JSON.stringify(response)}`;
}

SubmissionComplete.propTypes = {
  resource: PropTypes.shape({ read: PropTypes.func }),
};

export default SubmissionComplete;
