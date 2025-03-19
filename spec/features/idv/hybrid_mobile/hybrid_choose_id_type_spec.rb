require 'rails_helper'

RSpec.feature 'mobile hybrid flow choose id type', :js, :allow_net_connect_on_start do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper

  let(:phone_number) { '415-555-0199' }
  let(:sp) { :oidc }

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
  end

  it 'proofs and hands off to mobile', js: true do
    user = nil

    perform_in_browser(:desktop) do
      visit_idp_from_sp_with_ial2(sp)
      user = sign_up_and_2fa_ial1_user

      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
      expect(page).to have_content(t('doc_auth.info.you_entered'))
      expect(page).to have_content('+1 415-555-0199')

      # Confirm that Continue button is not shown when polling is enabled
      expect(page).not_to have_content(t('doc_auth.buttons.continue'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
    end
  end
end
