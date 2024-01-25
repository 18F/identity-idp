import type { ComponentProps } from 'react';
import { useContext } from 'react';
import { useI18n, HtmlTextWithStrongNoWrap } from '@18f/identity-react-i18n';
import { FormStepError } from '@18f/identity-form-steps';
import { Link } from '@18f/identity-components';
import formatHTML from '@18f/identity-react-i18n/format-html';
import MarketingSiteContext from '../context/marketing-site';

interface UnknownErrorProps extends ComponentProps<'p'> {
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  isFailedDocType: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  remainingAttempts: number;
  altFailedDocTypeMsg?: string | null;
  altIsFailedSelfieLivenessOrQualityMessage?: boolean;
  hasDismissed: boolean;
}

function formatIdTypeMsg({ altFailedDocTypeMsg, acceptedIdUrl }) {
  return formatHTML(altFailedDocTypeMsg, {
    a: ({ children }) => (
      <Link href={acceptedIdUrl} isExternal>
        {children}
      </Link>
    ),
  });
}

function UnknownError({
  unknownFieldErrors = [],
  isFailedDocType = false,
  isFailedSelfieLivenessOrQuality = false,
  remainingAttempts,
  altFailedDocTypeMsg = null,
  altIsFailedSelfieLivenessOrQualityMessage = false,
  hasDismissed,
}: UnknownErrorProps) {
  const { t } = useI18n();
  const { getHelpCenterURL } = useContext(MarketingSiteContext);
  const helpCenterLink = getHelpCenterURL({
    category: 'verify-your-identity',
    article: 'how-to-add-images-of-your-state-issued-id',
    location: 'document_capture_review_issues',
  });

  const acceptedIdUrl = getHelpCenterURL({
    category: 'verify-your-identity',
    article: 'accepted-identification-documents',
    location: 'document_capture_review_issues',
  });

  const errs =
    !!unknownFieldErrors &&
    unknownFieldErrors.filter((error) => !['front', 'back'].includes(error.field!));
  const err = errs.length !== 0 ? errs[0].error : null;
  if (isFailedDocType && !!altFailedDocTypeMsg) {
    return (
      <p key={altFailedDocTypeMsg}>{formatIdTypeMsg({ altFailedDocTypeMsg, acceptedIdUrl })}</p>
    );
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
  if (isFailedSelfieLivenessOrQuality && !!altIsFailedSelfieLivenessOrQualityMessage) {
    return <p>THIS IS THE REVIEW PAGE TEXT</p>;
  }
  if (isFailedSelfieLivenessOrQuality && err) {
    return (
      <p>
        UNKNOWN ERROR FAIL TEXT
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
        {err.message}{' '}
        <Link isExternal isNewTab href={helpCenterLink}>
          {t('doc_auth.info.review_examples_of_photos')}
        </Link>
      </p>
    );
  }
  return <p />;
}

export default UnknownError;
