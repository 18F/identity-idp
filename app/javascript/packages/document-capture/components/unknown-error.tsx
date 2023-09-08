import type { ComponentProps } from 'react';
import { useContext } from 'react';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { FormStepError } from '@18f/identity-form-steps';
import MarketingSiteContext from '../context/marketing-site';

interface UnknownErrorProps extends ComponentProps<'p'> {
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  isFailedDocType: boolean;
  remainingAttempts: number;
  altFailedDocTypeMsg?: string | null;
  hasDismissed: boolean;
}

function UnknownError({
  unknownFieldErrors = [],
  isFailedDocType = false,
  remainingAttempts,
  altFailedDocTypeMsg = null,
  hasDismissed,
}: UnknownErrorProps) {
  const { t } = useI18n();
  const { getHelpCenterURL } = useContext(MarketingSiteContext);
  const helpCenterLink = getHelpCenterURL({
    category: 'verify-your-identity',
    article: 'how-to-add-images-of-your-state-issued-id',
    location: 'document_capture_review_issues',
  });
  const errs =
    !!unknownFieldErrors &&
    unknownFieldErrors.filter((error) => !['front', 'back'].includes(error.field!));
  const err = errs.length !== 0 ? errs[0].error : null;
  if (isFailedDocType && !!altFailedDocTypeMsg) {
    return <p key={altFailedDocTypeMsg}>{altFailedDocTypeMsg}</p>;
  }
  if (isFailedDocType && err) {
    return (
      <p key={`${err.message}-${remainingAttempts}`}>
        {err.message}{' '}
        <HtmlTextWithStrongNoWrap
          text={t('idv.warning.attempts_html', { count: remainingAttempts })}
        />
      </p>
    );
  }
  if (err && !hasDismissed) {
    return <p key={err.message}>{err.message}</p>;
  }
  if (err && hasDismissed) {
    return (
      <p key={err.message}>
        {err.message} <a href={helpCenterLink}>{t('doc_auth.info.review_examples_of_photos')}</a>
      </p>
    );
  }
  return <p />;
}

export default UnknownError;
