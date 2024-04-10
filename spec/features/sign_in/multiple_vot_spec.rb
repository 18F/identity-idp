require 'rails_helper'

RSpec.feature 'Sign in with multiple vectors of trust', allowed_extra_analytics: [:*] do
  include OidcAuthHelper
  include IdvHelper
  include DocAuthHelper

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
  end

  context 'biometric and non-biometric proofing is acceptable' do
    scenario 'identity proofing is not required if user is proofed with biometric' do
      user = create(:user, :proofed_with_selfie)

      visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to be_present
      expect(user_info[:vot]).to eq('C1.C2.P1.Pb')
    end

    scenario 'identity proofing is not required if user is proofed without biometric' do
      user = create(:user, :proofed)

      visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to be_present
      expect(user_info[:vot]).to eq('C1.C2.P1')
    end

    scenario 'identity proofing with biometric is required if user is not proofed', :js do
      user = create(:user, :fully_registered)

      visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(idv_welcome_path)
      complete_all_doc_auth_steps_before_password_step(with_selfie: true)
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to be_present
      expect(user_info[:vot]).to eq('C1.C2.P1.Pb')
    end
  end

  context 'proofing or no proofing is acceptable (IALMAX)' do
    scenario 'identity proofing is not required if the user is not proofed' do
      user = create(:user, :fully_registered)

      visit_idp_from_oidc_sp_with_vtr(
        vtr: ['C1.C2.P1', 'C1.C2'],
        scope: 'openid email profile:name',
      )
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to_not be_present
      expect(user_info[:vot]).to eq('C1.C2')
    end

    scenario 'attributes are shared if the user is proofed' do
      user = create(:user, :proofed)

      visit_idp_from_oidc_sp_with_vtr(
        vtr: ['C1.C2.P1', 'C1.C2'],
        scope: 'openid email profile:name',
      )
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to be_present
      expect(user_info[:vot]).to eq('C1.C2.P1')
    end

    scenario 'identity proofing is not required if proofed user resets password' do
      user = create(:user, :proofed)

      visit_idp_from_oidc_sp_with_vtr(
        vtr: ['C1.C2.P1', 'C1.C2'],
        scope: 'openid email profile:name',
      )
      trigger_reset_password_and_click_email_link(user.email)
      reset_password(user, 'new even better password')
      user.password = 'new even better password'
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(sign_up_completed_path)
      click_agree_and_continue

      user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

      expect(user_info[:given_name]).to_not be_present
      expect(user_info[:vot]).to eq('C1.C2')
    end
  end
end
