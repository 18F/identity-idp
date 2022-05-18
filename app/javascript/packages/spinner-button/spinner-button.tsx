import { useRef, useImperativeHandle, forwardRef } from 'react';
import type { HTMLAttributes, RefAttributes, ForwardedRef } from 'react';
import { Button } from '@18f/identity-components';
import type { ButtonProps } from '@18f/identity-components';
import type { SpinnerButtonElement } from './spinner-button-element';
import './spinner-button-element';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'lg-spinner-button': HTMLAttributes<SpinnerButtonElement> &
        RefAttributes<SpinnerButtonElement> & { class?: string };
    }
  }
}

interface SpinnerButtonProps extends ButtonProps {
  /**
   * Whether to start spinner automatically on click.
   */
  spinOnClick?: boolean;

  /**
   * Text to show after long delay in processing.
   */
  actionMessage?: string;

  /**
   * Time after which to show action message, in milliseconds.
   */
  longWaitDurationMs?: number;
}

export type SpinnerButtonRefHandle = SpinnerButtonElement;

function SpinnerButton(
  {
    spinOnClick = true,
    actionMessage,
    longWaitDurationMs,
    isOutline,
    ...buttonProps
  }: SpinnerButtonProps,
  ref: ForwardedRef<SpinnerButtonElement | null>,
) {
  const elementRef = useRef<SpinnerButtonRefHandle>(null);
  useImperativeHandle(ref, () => elementRef.current!);

  const classes = isOutline ? 'spinner-button--outline' : undefined;

  return (
    <lg-spinner-button
      spin-on-click={spinOnClick}
      long-wait-duration-ms={longWaitDurationMs}
      ref={elementRef}
      class={classes}
    >
      <div className="spinner-button__content">
        <Button isOutline={isOutline} {...buttonProps} />
        <span className="spinner-dots spinner-dots--centered" aria-hidden="true">
          <span className="spinner-dots__dot" />
          <span className="spinner-dots__dot" />
          <span className="spinner-dots__dot" />
        </span>
      </div>
      {actionMessage && (
        <div
          role="status"
          data-message={actionMessage}
          className="spinner-button__action-message usa-sr-only"
        />
      )}
    </lg-spinner-button>
  );
}

export default forwardRef(SpinnerButton);
