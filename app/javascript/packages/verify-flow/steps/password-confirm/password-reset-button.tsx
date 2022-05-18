import { SpinnerButton } from '@18f/identity-spinner-button';
import { t } from '@18f/identity-i18n';
import { isErrorResponse, post } from '../../services/api';
import type { ErrorResponse } from '../../services/api';

/**
 * API endpoint for password reset.
 */
export const API_ENDPOINT = '/api/verify/v2/password_reset';

/**
 * API response shape.
 */
interface PasswordResetSuccessResponse {
  redirect_url: string;
}

/**
 * API response shape.
 */
type PasswordResetResponse = PasswordResetSuccessResponse | ErrorResponse;

/**
 * Navigates user to the given URL.
 *
 * @param url Destination URL.
 */
function navigate(url) {
  window.location.href = url;
}

function PasswordResetButton({ onNavigate = navigate }) {
  async function requestReset() {
    const json = await post<PasswordResetResponse>(API_ENDPOINT, {}, { csrf: true, json: true });
    if (!isErrorResponse(json)) {
      const { redirect_url: redirectURL } = json;
      onNavigate(redirectURL);
    }
  }

  return (
    <SpinnerButton isBig isOutline isWide onClick={requestReset}>
      {t('idv.forgot_password.reset_password')}
    </SpinnerButton>
  );
}

export default PasswordResetButton;
