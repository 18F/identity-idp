import { useContext, useEffect, useRef } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import FormStepsContext from './form-steps-context';

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
  const ref = useRef<SpinnerButtonRefHandle>(null);
  const { isSubmitting } = useContext(FormStepsContext);
  useEffect(() => ref.current?.toggleSpinner(isSubmitting), [isSubmitting]);

  const classes = ['margin-y-5', className].filter(Boolean).join(' ');

  return (
    <div className={classes}>
      <SpinnerButton ref={ref} spinOnClick={false} type="submit" isBig isWide>
        {children}
      </SpinnerButton>
    </div>
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
