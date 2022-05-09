import { post } from '../../services/api';
import type { VerifyFlowValues } from '../../verify-flow';

interface PasswordConfirmResponse {
  personal_key: string;
}

async function submit({ userBundleToken, password }: VerifyFlowValues) {
  const json = await post<PasswordConfirmResponse>({
    user_bundle_token: userBundleToken,
    password,
  });

  return { personalKey: json.personal_key };
}

export default submit;
