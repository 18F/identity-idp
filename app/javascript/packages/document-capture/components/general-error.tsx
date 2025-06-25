import type { ComponentProps } from 'react';
import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormStepError } from '@18f/identity-form-steps';
import { Link } from '@18f/identity-components';
import formatHTML from '@18f/identity-react-i18n/format-html';
import MarketingSiteContext from '../context/marketing-site';
import { InPersonContext } from '../context';

interface GeneralErrorProps extends ComponentProps<'p'> {
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
  isFailedDocType: boolean;
  isFailedSelfie: boolean;
  isFailedSelfieLivenessOrQuality: boolean;
  isPassportError?: boolean;
  altFailedDocTypeMsg?: string | null;
  altIsFailedSelfieDontIncludeAttempts?: boolean;
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

type GetErrorArguments = {
  unknownFieldErrors: FormStepError<{ front: string; back: string }>[];
};
function getError({ unknownFieldErrors }: GetErrorArguments) {
  const errs =
    !!unknownFieldErrors &&
    // Errors where the field than is not 'front' or 'back'. In practice this means the field
    // should be from the 'general' field in the "IdV: doc auth image upload vendor submitted" event
    unknownFieldErrors.filter((error) => !['front', 'back'].includes(error.field!));
  const err = errs.length !== 0 ? errs[0].error : null;

  return err;
}

function isNetworkError(unknownFieldErrors) {
  return unknownFieldErrors.some((error) => error.field === 'network');
}

function GeneralError({
  unknownFieldErrors = [],
  isFailedDocType = false,
  isFailedSelfie = false,
  isFailedSelfieLivenessOrQuality = false,
  isPassportError = false,
  altFailedDocTypeMsg = null,
  altIsFailedSelfieDontIncludeAttempts = false,
  hasDismissed,
}: GeneralErrorProps) {
  const { t } = useI18n();
  const { getHelpCenterURL } = useContext(MarketingSiteContext);
  const { chooseIdTypePath } = useContext(InPersonContext);
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

  const err = getError({ unknownFieldErrors });
  const isNetwork = isNetworkError(unknownFieldErrors);

  if (isFailedDocType && !!altFailedDocTypeMsg) {
    return (
      <p key={altFailedDocTypeMsg}>{formatIdTypeMsg({ altFailedDocTypeMsg, acceptedIdUrl })}</p>
    );
  }
  if (isFailedDocType && err) {
    return <p key={err.message}>{err.message}</p>;
  }
  if ((isFailedSelfieLivenessOrQuality || isFailedSelfie) && err) {
    let selfieHelpCenterLinkText = t('doc_auth.errors.general.selfie_failure_help_link_text');
    const helpCenterURL = new URL(helpCenterLink);
    if (isFailedSelfieLivenessOrQuality) {
      helpCenterURL.hash = 'how-to-add-a-photo-of-your-face-to-help-verify-your-id';
      selfieHelpCenterLinkText = t('doc_auth.errors.alerts.selfie_not_live_help_link_text');
    }
    return (
      <p>
        {err.message}{' '}
        {altIsFailedSelfieDontIncludeAttempts && (
          <Link isExternal isNewTab href={helpCenterURL.toString()}>
            {selfieHelpCenterLinkText}
          </Link>
        )}
      </p>
    );
  }
  if (isPassportError) {
    if (!isNetwork) {
      return <p>{t('doc_auth.info.review_passport')}</p>;
    }
    return (
      <p key={err?.message}>
        {t('doc_auth.errors.general.network_error_passport')}{' '}
        <Link href={chooseIdTypePath || ''} isExternal={false}>
          {t('doc_auth.errors.general.network_error_passport_link_text')}
        </Link>{' '}
        {t('doc_auth.errors.general.network_error_passport_ending')}
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

export default GeneralError;
