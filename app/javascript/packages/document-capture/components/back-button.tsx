import type { ComponentProps } from 'react';

import { Button } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';

interface BackLinkProps extends ComponentProps<typeof Button> {
  includeBorder?: boolean;
}

function BackButton({ includeBorder = false, ...props }: BackLinkProps) {
  const button = (
    <Button isUnstyled {...props}>
      &#x2039; {t('forms.buttons.back')}
    </Button>
  );
  if (includeBorder) {
    return (
      <div className="margin-top-5 padding-top-2 border-top border-primary-light">{button}</div>
    );
  }
  return button;
}

export default BackButton;
