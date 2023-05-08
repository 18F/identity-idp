import { forwardRef, useImperativeHandle, useRef, useEffect } from 'react';
import type { ReactNode, ForwardedRef, MutableRefObject } from 'react';
import { createPortal } from 'react-dom';
import type { FocusTrap } from 'focus-trap';
import { useI18n } from '@18f/identity-react-i18n';
import { useIfStillMounted, useImmutableCallback } from '@18f/identity-react-hooks';
import { getAssetPath } from '@18f/identity-assets';
import useToggleBodyClassByPresence from './hooks/use-toggle-body-class-by-presence';
import useFocusTrap from './hooks/use-focus-trap';

type BackgroundColor = 'white' | 'none';

interface FullScreenProps {
  /**
   * Callback invoked when user initiates close intent.
   */
  onRequestClose?: () => void;

  /**
   * Accessible label for modal.
   */
  label?: string;

  /**
   * Whether to omit default close button, in case it is implemented by full screen content.
   */
  hideCloseButton?: boolean;

  /**
   * Background color of full-screen dialog. Defaults to "white".
   */
  bgColor?: BackgroundColor;

  /**
   * Identifier of element(s) which label the modal.
   */
  labelledBy?: string;

  /**
   * Identifier of element(s) which describe the modal.
   */
  describedBy?: string;

  /**
   * Child elements.
   */
  children: ReactNode;
}

export interface FullScreenRefHandle {
  focusTrap: FocusTrap | null;
}

export function useInertSiblingElements(containerRef: MutableRefObject<HTMLElement | null>) {
  useEffect(() => {
    const container = containerRef.current;

    const originalElementAttributeValues: [Element, string | null][] = [];
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

function FullScreen(
  {
    onRequestClose = () => {},
    label,
    hideCloseButton = false,
    bgColor = 'white',
    labelledBy,
    describedBy,
    children,
  }: FullScreenProps,
  ref: ForwardedRef<FullScreenRefHandle>,
) {
  const { t } = useI18n();
  const ifStillMounted = useIfStillMounted();
  const containerRef = useRef(null as HTMLDivElement | null);
  const onFocusTrapDeactivate = useImmutableCallback(ifStillMounted(onRequestClose));
  const focusTrap = useFocusTrap(containerRef, {
    clickOutsideDeactivates: true,
    onDeactivate: onFocusTrapDeactivate,
  });
  useImperativeHandle(ref, () => ({ focusTrap }), [focusTrap]);
  useToggleBodyClassByPresence('has-full-screen-overlay', FullScreen);
  useInertSiblingElements(containerRef);

  return createPortal(
    <div
      ref={containerRef}
      role="dialog"
      aria-label={label}
      aria-labelledby={labelledBy}
      aria-describedby={describedBy}
      className={`full-screen bg-${bgColor}`}
    >
      {children}
      {!hideCloseButton && (
        <button
          type="button"
          aria-label={t('account.navigation.close')}
          onClick={onRequestClose}
          className="full-screen__close-button usa-button padding-2 margin-2"
        >
          <img
            alt=""
            src={getAssetPath('close-white-alt.svg')}
            className="full-screen__close-icon"
          />
        </button>
      )}
    </div>,
    document.body,
  );
}

export default forwardRef(FullScreen);
