import React from 'react';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef {"success"|"warning"|"error"|"info"|"other"} AlertType
 */

/**
 * @typedef AlertProps
 *
 * @prop {AlertType=} type     Alert type. Defaults to "other".
 * @prop {ReactNode}  children Child elements.
 */

/**
 * @param {AlertProps} props Props object.
 */
function Alert({ type = 'other', children }) {
  return (
    <div className={`usa-alert usa-alert--${type}`}>
      <div className="usa-alert__body">
        <p className="usa-alert__text">{children}</p>
      </div>
    </div>
  );
}

export default Alert;
