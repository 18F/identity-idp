import { post } from '../../services/api';
import type { VerifyFlowValues } from '../../verify-flow';

/**
 * API endpoint for password confirmation submission.
 */
export const API_ENDPOINT = '/api/verify/v2/password_confirm';

/**
 * API response shape.
 */
interface PasswordConfirmResponse {
  personal_key: string;
}

async function submit({ userBundleToken, password }: VerifyFlowValues) {
  const payload = { user_bundle_token: userBundleToken, password };
  const json = await post<PasswordConfirmResponse>(API_ENDPOINT, payload, {
    json: true,
    csrf: true,
  });

  return { personalKey: json.personal_key };
}

export default submit;
