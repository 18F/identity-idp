import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

interface FormStepsButtonProps {
  /**
   * Optional additional class names to apply to button.
   */
  className?: string;

  /**
   * Button label.
   */
  children: string;
}

function FormStepsButton({ className, children }: FormStepsButtonProps) {
  const classes = ['display-block', 'margin-y-5', className].filter(Boolean).join(' ');

  return (
    <Button type="submit" isBig isWide className={classes}>
      {children}
    </Button>
  );
}

export default {
  Continue(props: Omit<FormStepsButtonProps, 'children'>) {
    const { t } = useI18n();
    return <FormStepsButton {...props}>{t('forms.buttons.continue')}</FormStepsButton>;
  },
  Submit(props: Omit<FormStepsButtonProps, 'children'>) {
    const { t } = useI18n();
    return <FormStepsButton {...props}>{t('forms.buttons.submit.default')}</FormStepsButton>;
  },
};
