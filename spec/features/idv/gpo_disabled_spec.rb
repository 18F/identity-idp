require 'rails_helper'

RSpec.feature 'disabling GPO address verification' do
  include IdvStepHelper

  context 'with GPO address verification disabled' do
    before do
      allow(FeatureManagement).to receive(:gpo_verification_enabled?).and_return(false)
      # Whether GPO is available affects the routes that are available
      # We want path helpers for unavailable routes to raise and fail the tests
      # so we reload the routes here
      Rails.application.reload_routes!
    end

    after do
      allow(FeatureManagement).to receive(:gpo_verification_enabled?).and_call_original
      Rails.application.reload_routes!
    end

    it 'allows verification without the option to confirm address with usps', :js do
      user = user_with_2fa
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      # Link to the GPO flow should not be visible
      expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

      fill_out_phone_form_ok('2342255432')
      choose_idv_otp_delivery_method_sms
      fill_in_code_with_last_phone_otp
      click_submit_default
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(sign_up_completed_path)
    end
  end

  context 'GPO address verification disallowed for facial match comparison' do
    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    end

    it 'does not allow verify by mail with facial match comparison', :js do
      user = user_with_2fa
      start_idv_from_sp(:oidc, facial_match_required: true)
      sign_in_and_2fa_user(user)
      complete_all_doc_auth_steps(with_selfie: true)

      # Link to the GPO flow should not be visible
      expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

      # Directly visiting the verify my mail path does not allow the user to request a letter
      visit idv_request_letter_path
      expect(page).to have_current_path(idv_phone_path)
    end

    it 'does allow verify by mail without facial match comparison', :js do
      user = user_with_2fa
      start_idv_from_sp(:oidc, facial_match_required: false)
      sign_in_and_2fa_user(user)
      complete_all_doc_auth_steps(with_selfie: false)
      click_on t('idv.troubleshooting.options.verify_by_mail')

      # The user is allowed to visit the request letter path
      expect(page).to have_current_path(idv_request_letter_path)
    end
  end
end
