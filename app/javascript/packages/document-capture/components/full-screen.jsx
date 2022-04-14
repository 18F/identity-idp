import { forwardRef, useImperativeHandle, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { useI18n } from '@18f/identity-react-i18n';
import { useIfStillMounted } from '@18f/identity-react-hooks';
import useAsset from '../hooks/use-asset';
import useToggleBodyClassByPresence from '../hooks/use-toggle-body-class-by-presence';
import useImmutableCallback from '../hooks/use-immutable-callback';
import useFocusTrap from '../hooks/use-focus-trap';

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
 * @typedef {{focusTrap: import('focus-trap').FocusTrap?}} FullScreenRefHandle
 */

/**
 * @param {React.MutableRefObject<HTMLElement?>} containerRef
 */
export function useInertSiblingElements(containerRef) {
  useEffect(() => {
    const container = containerRef.current;

    /**
     * @type {[Element, string|null][]}
     */
    const originalElementAttributeValues = [];
    if (container && container.parentNode) {
      for (const child of container.parentNode.children) {
        if (child !== container) {
          originalElementAttributeValues.push([child, child.getAttribute('aria-hidden')]);
          child.setAttribute('aria-hidden', 'true');
        }
      }
    }

    return () =>
      originalElementAttributeValues.forEach(([child, ariaHidden]) =>
        ariaHidden === null
          ? child.removeAttribute('aria-hidden')
          : child.setAttribute('aria-hidden', ariaHidden),
      );
  });
}

/**
 * @param {FullScreenProps} props Props object.
 * @param {import('react').ForwardedRef<FullScreenRefHandle>} ref
 */
function FullScreen({ onRequestClose = () => {}, label, children }, ref) {
  const { t } = useI18n();
  const { getAssetPath } = useAsset();
  const ifStillMounted = useIfStillMounted();
  const containerRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const onFocusTrapDeactivate = useImmutableCallback(ifStillMounted(onRequestClose));
  const focusTrap = useFocusTrap(containerRef, {
    clickOutsideDeactivates: true,
    onDeactivate: onFocusTrapDeactivate,
  });
  useImperativeHandle(ref, () => ({ focusTrap }), [focusTrap]);
  useToggleBodyClassByPresence('has-full-screen-overlay', FullScreen);
  useInertSiblingElements(containerRef);

  return createPortal(
    <div ref={containerRef} role="dialog" aria-label={label} className="full-screen bg-white">
      {children}
      <button
        type="button"
        aria-label={t('users.personal_key.close')}
        onClick={onRequestClose}
        className="full-screen__close-button usa-button padding-2 margin-2"
      >
        <img alt="" src={getAssetPath('close-white-alt.svg')} className="full-screen__close-icon" />
      </button>
    </div>,
    document.body,
  );
}

export default forwardRef(FullScreen);
