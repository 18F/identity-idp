import type { ComponentProps } from 'react';
import { ReactNode } from 'react';
import { formatHTML, useI18n } from '@18f/identity-react-i18n';
import { FormStepError } from '@18f/identity-form-steps';

interface UnknownErrorProps extends ComponentProps<'p'> {
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  isFailedDocType: boolean;
  remainingAttempts: number;
  altFailedDocTypeMsg?: string | null;
}

function formatWithStrongNoWrap(text: string): ReactNode {
  return formatHTML(text, {
    strong: ({ children }) => <strong className="text-no-wrap">{children}</strong>,
  });
}

function UnknownError({
  unknownFieldErrors = [],
  isFailedDocType = false,
  remainingAttempts,
  altFailedDocTypeMsg = null,
}: UnknownErrorProps) {
  const { t } = useI18n();
  const errs =
    !!unknownFieldErrors &&
    unknownFieldErrors.filter((error) => !['front', 'back'].includes(error.field!));
  const err = errs.length !== 0 ? errs[0].error : null;
  if (isFailedDocType && !!altFailedDocTypeMsg) {
    return <p>{altFailedDocTypeMsg}</p>;
  }
  if (isFailedDocType && err) {
    return (
      <p key={`${err.message}-${remainingAttempts}`}>
        {err.message}{' '}
        {formatWithStrongNoWrap(t('idv.warning.attempts_html', { count: remainingAttempts }))}
      </p>
    );
  }
  if (err) {
    return <p key={err.message}>{err.message}</p>;
  }
  return <p />;
}

export default UnknownError;
