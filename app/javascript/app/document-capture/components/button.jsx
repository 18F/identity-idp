import React from 'react';
import PropTypes from 'prop-types';

function Button({
  type,
  onClick,
  children,
  isPrimary,
  isSecondary,
  isDisabled,
  isUnstyled,
  className,
}) {
  const classes = [
    'btn',
    isPrimary && 'btn-primary btn-wide',
    isSecondary && 'btn-secondary',
    isUnstyled && 'btn-link',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    // Disable reason: We can assume `type` is provided as valid, or the default `button`.
    // eslint-disable-next-line react/button-has-type
    <button type={type} onClick={onClick} disabled={isDisabled} className={classes}>
      {children}
    </button>
  );
}

Button.propTypes = {
  type: PropTypes.string,
  onClick: PropTypes.func,
  children: PropTypes.node,
  isPrimary: PropTypes.bool,
  isSecondary: PropTypes.bool,
  isDisabled: PropTypes.bool,
  isUnstyled: PropTypes.bool,
  className: PropTypes.string,
};

Button.defaultProps = {
  type: 'button',
  onClick: undefined,
  children: null,
  isPrimary: false,
  isSecondary: false,
  isDisabled: false,
  isUnstyled: false,
  className: undefined,
};

export default Button;
