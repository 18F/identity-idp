import type { HTMLAttributes } from 'react';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';
import type { ButtonProps } from '@18f/identity-components';
import type PrintButtonElement from './print-button-element';
import './print-button-element';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'lg-print-button': HTMLAttributes<PrintButtonElement> & { class?: string };
    }
  }
}

function PrintButton(buttonProps: ButtonProps) {
  return (
    <lg-print-button>
      <Button icon="print" {...buttonProps}>
        {t('components.print_button.label')}
      </Button>
    </lg-print-button>
  );
}

export default PrintButton;
