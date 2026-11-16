require 'rails_helper'

RSpec.describe 'MFA setup for an account whose only credential is a personal key', type: :request do
  let(:user) { create(:user, password: RequestHelper::VALID_PASSWORD) }
  let!(:raw_key) { PersonalKeyGenerator.new(user).generate! }

  before do
    allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
      .and_return(deprecation_phase_1_enabled)
    post new_user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  shared_examples 'the password alone does not reach setup' do
    it 'sends the password-only session to personal key verification' do
      get user_two_factor_authentication_path

      expect(response).to redirect_to(login_two_factor_personal_key_path)
    end

    it 'refuses to add an authentication method before the key is verified' do
      post backup_code_setup_path

      expect(response).to redirect_to(login_two_factor_personal_key_path)
      expect(user.reload.backup_code_configurations).to be_empty
    end

    it 'allows setup once the personal key has been verified' do
      post login_two_factor_personal_key_path,
           params: { personal_key_form: { personal_key: raw_key } }
      expect(response).to redirect_to(authentication_methods_setup_path)

      get authentication_methods_setup_path

      expect(response).to have_http_status(:ok)
    end
  end

  context 'with the personal key deprecation flag off' do
    let(:deprecation_phase_1_enabled) { false }

    it_behaves_like 'the password alone does not reach setup'
  end

  context 'with the personal key deprecation flag on' do
    let(:deprecation_phase_1_enabled) { true }

    it_behaves_like 'the password alone does not reach setup'
  end
end
