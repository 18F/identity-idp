import React, { useRef, useEffect, useCallback } from 'react';
import { createFocusTrap } from 'focus-trap';
import useI18n from '../hooks/use-i18n';
import useAsset from '../hooks/use-asset';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FullScreenProps
 *
 * @prop {()=>void=} onRequestClose Callback invoked when user initiates close intent.
 * @prop {ReactNode} children       Child elements.
 */

/**
 * Number of active instances of FullScreen currently mounted, used in determining when overlay body
 * class should be added or removed.
 *
 * @type {number}
 */
let activeInstances = 0;

/**
 * @param {FullScreenProps} props Props object.
 */
function FullScreen({ onRequestClose = () => {}, children }) {
  const { t } = useI18n();
  const { getAssetPath } = useAsset();
  const trapRef = useRef(/** @type {?import('focus-trap').FocusTrap} */ (null));
  const onRequestCloseRef = useRef(onRequestClose);
  useEffect(() => {
    // Since the focus trap is only initialized once, but the callback could
    // be changed, ensure that the current reference is kept as a mutable value
    // to reference in the deactivation.
    onRequestCloseRef.current = onRequestClose;
  }, [onRequestClose]);

  const setFocusTrapRef = useCallback((node) => {
    if (trapRef.current) {
      trapRef.current.deactivate();
    }

    if (node) {
      trapRef.current = createFocusTrap(node, {
        onDeactivate: () => onRequestCloseRef.current(),
      });

      trapRef.current.activate();
    }
  }, []);

  useEffect(() => {
    if (activeInstances++ === 0) {
      document.body.classList.add('has-full-screen-overlay');
    }

    return () => {
      if (--activeInstances === 0) {
        document.body.classList.remove('has-full-screen-overlay');
      }
    };
  }, []);

  return (
    <div ref={setFocusTrapRef} aria-modal="true" className="full-screen bg-white">
      <button
        type="button"
        aria-label={t('users.personal_key.close')}
        onClick={() => trapRef.current?.deactivate()}
        className="full-screen-close-button usa-button padding-2 margin-2"
      >
        <img alt="" src={getAssetPath('close-white-alt.svg')} className="full-screen-close-icon" />
      </button>
      {children}
    </div>
  );
}

export default FullScreen;
