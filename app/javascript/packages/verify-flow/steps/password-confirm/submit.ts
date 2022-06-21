import { FormError } from '@18f/identity-form-steps';
import { post, ErrorResponse, isErrorResponse } from '../../services/api';
import type { VerifyFlowValues } from '../../verify-flow';

/**
 * API endpoint for password confirmation submission.
 */
export const API_ENDPOINT = '/api/verify/v2/password_confirm';

export class PasswordSubmitError extends FormError {}

/**
 * Successful API response shape.
 */
interface PasswordConfirmSuccessResponse {
  /**
   * Personal key generated for the user profile.
   */
  personal_key: string;

  /**
   * Final redirect URL for this verification session.
   */
  completion_url: string;
}

/**
 * Failed API response shape.
 */
type PasswordConfirmErrorResponse = ErrorResponse<'password'>;

/**
 * API response shape.
 */
type PasswordConfirmResponse = PasswordConfirmSuccessResponse | PasswordConfirmErrorResponse;

async function submit({
  userBundleToken,
  password,
}: VerifyFlowValues): Promise<Partial<VerifyFlowValues>> {
  const payload = { user_bundle_token: userBundleToken, password };
  const json = await post<PasswordConfirmResponse>(API_ENDPOINT, payload, {
    json: true,
    csrf: true,
  });

  if (isErrorResponse(json)) {
    const [field, [error]] = Object.entries(json.errors)[0];
    throw new PasswordSubmitError(error, { field });
  }

  return { personalKey: json.personal_key, completionURL: json.completion_url };
}

export default submit;
