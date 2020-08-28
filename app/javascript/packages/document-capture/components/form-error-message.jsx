import React from 'react';
import { RequiredValueMissingError } from './form-steps';
import { UploadFormEntryError } from '../services/upload';
import useI18n from '../hooks/use-i18n';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FormErrorMessageProps
 *
 * @prop {Error} error Error for which message should be generated.
 */

/**
 * @param {FormErrorMessageProps} props Props object.
 */
function FormErrorMessage({ error }) {
  const { t } = useI18n();

  if (error instanceof RequiredValueMissingError) {
    return <>{t('simple_form.required.text')}</>;
  }

  if (error instanceof UploadFormEntryError) {
    return <>{error.message}</>;
  }

  return null;
}

export default FormErrorMessage;
