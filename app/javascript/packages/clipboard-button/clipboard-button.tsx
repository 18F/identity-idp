import type { HTMLAttributes } from 'react';
import { Button } from '@18f/identity-components';
import type { ButtonProps } from '@18f/identity-components';
import type { ClipboardButtonElement } from './clipboard-button-element';
import './clipboard-button-element';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'lg-clipboard-button': HTMLAttributes<ClipboardButtonElement> & { class?: string };
    }
  }
}

interface ClipboardButtonProps {
  /**
   * Text to be copied to the clipboard upon click.
   */
  clipboardText: string;
}

function ClipboardButton({ clipboardText, ...buttonProps }: ClipboardButtonProps & ButtonProps) {
  return (
    <lg-clipboard-button data-clipboard-text={clipboardText}>
      <Button {...buttonProps} />
    </lg-clipboard-button>
  );
}

export default ClipboardButton;
