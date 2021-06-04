import { useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { createFocusTrap } from 'focus-trap';
import useI18n from '../hooks/use-i18n';
import useAsset from '../hooks/use-asset';
import useToggleBodyClassByPresence from '../hooks/use-toggle-body-class-by-presence';
import useImmutableCallback from '../hooks/use-immutable-callback';

/** @typedef {import('focus-trap').FocusTrap} FocusTrap */
/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FullScreenProps
 *
 * @prop {()=>void=} onRequestClose Callback invoked when user initiates close intent.
 * @prop {string} label Accessible label for modal.
 * @prop {ReactNode} children Child elements.
 */

/**
 * @param {React.MutableRefObject<HTMLElement?>} containerRef
 * @param {import('focus-trap').Options=} options
 */
function useFocusTrap(containerRef, options) {
  const trapRef = useRef(/** @type {FocusTrap?} */ (null));

  useEffect(() => {
    if (containerRef.current) {
      trapRef.current = createFocusTrap(containerRef.current, options);

      trapRef.current.activate();
    }

    return () => {
      trapRef.current?.deactivate();
    };
  }, []);
}

/**
 * @param {React.MutableRefObject<HTMLElement?>} containerRef
 */
function useSoleAccessibleContent(containerRef) {
  useEffect(() => {
    const container = containerRef.current;

    /**
     * @type {Element[]}
     */
    let siblings = [];
    if (container && container.parentNode) {
      siblings = Array.from(container.parentNode.children).filter(
        (node) => node !== container && !node.hasAttribute('aria-hidden'),
      );
    }

    siblings.forEach((node) => node.setAttribute('aria-hidden', 'true'));
    return () => siblings.forEach((node) => node.removeAttribute('aria-hidden'));
  });
}

/**
 * @param {FullScreenProps} props Props object.
 */
function FullScreen({ onRequestClose = () => {}, label, children }) {
  const { t } = useI18n();
  const { getAssetPath } = useAsset();
  const containerRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const onFocusTrapDeactivate = useImmutableCallback(onRequestClose);
  useFocusTrap(containerRef, {
    clickOutsideDeactivates: true,
    onDeactivate: onFocusTrapDeactivate,
  });
  useToggleBodyClassByPresence('has-full-screen-overlay', FullScreen);
  useSoleAccessibleContent(containerRef);

  return createPortal(
    <div ref={containerRef} role="dialog" aria-label={label} className="full-screen bg-white">
      {children}
      <button
        type="button"
        aria-label={t('users.personal_key.close')}
        onClick={onRequestClose}
        className="full-screen-close-button usa-button padding-2 margin-2"
      >
        <img alt="" src={getAssetPath('close-white-alt.svg')} className="full-screen-close-icon" />
      </button>
    </div>,
    document.body,
  );
}

export default FullScreen;
