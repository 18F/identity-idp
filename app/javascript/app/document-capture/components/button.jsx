import React from 'react';
import PropTypes from 'prop-types';

function Button({ type, onClick, children, isPrimary, isDisabled, className }) {
  const classes = ['btn', isPrimary && 'btn-primary btn-wide', className].filter(Boolean).join(' ');

  // Disable reason: We can assume `type` is provided as valid, or the default `button`.

  return (
    // eslint-disable-next-line react/button-has-type
    <button type={type} onClick={() => onClick()} disabled={isDisabled} className={classes}>
      {children}
    </button>
  );
}

Button.propTypes = {
  type: PropTypes.string,
  onClick: PropTypes.func,
  children: PropTypes.node,
  isPrimary: PropTypes.bool,
  isDisabled: PropTypes.bool,
  className: PropTypes.string,
};

Button.defaultProps = {
  type: 'button',
  onClick: () => {},
  children: null,
  isPrimary: false,
  isDisabled: false,
  className: undefined,
};

export default Button;
