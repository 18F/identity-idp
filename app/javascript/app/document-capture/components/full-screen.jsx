import React, { useRef, useEffect } from 'react';
import PropTypes from 'prop-types';
import createFocusTrap from 'focus-trap';
import Image from './image';
import useI18n from '../hooks/use-i18n';

function FullScreen({ onRequestClose, children }) {
  const t = useI18n();
  const modalRef = useRef(/** @type {?HTMLDivElement} */ (null));
  const trapRef = useRef(/** @type {?import('focus-trap').FocusTrap} */ (null));
  const onRequestCloseRef = useRef(onRequestClose);
  useEffect(() => {
    // Since the focus trap is only initialized once, but the callback could
    // be changed, ensure that the current reference is kept as a mutable value
    // to reference in the deactivation.
    onRequestCloseRef.current = onRequestClose;
  }, [onRequestClose]);
  useEffect(() => {
    trapRef.current = createFocusTrap(modalRef.current, {
      onDeactivate: () => onRequestCloseRef.current(),
    });
    trapRef.current.activate();
    return trapRef.current.deactivate;
  }, []);

  return (
    <div ref={modalRef} aria-modal="true" className="full-screen bg-white">
      <button
        type="button"
        aria-label={t('users.personal_key.close')}
        onClick={() => trapRef.current.deactivate()}
        className="full-screen-close-button usa-button padding-2 margin-2"
      >
        <Image alt="" assetPath="close-white-alt.svg" className="full-screen-close-icon" />
      </button>
      {children}
    </div>
  );
}

FullScreen.propTypes = {
  onRequestClose: PropTypes.func,
  children: PropTypes.node.isRequired,
};

FullScreen.defaultProps = {
  onRequestClose: () => {},
};

export default FullScreen;
