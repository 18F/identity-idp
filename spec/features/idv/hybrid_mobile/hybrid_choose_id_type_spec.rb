require 'rails_helper'

RSpec.feature 'mobile hybrid flow choose id type', :js do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper
  include AbTestsHelper

  let(:phone_number) { '415-555-0199' }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('mock')
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
    reload_ab_tests
  end

  after do
    reload_ab_tests
  end

  it 'choose id type screen before doc capture in hybrid flow and proceeds after passport select',
     js: true do
    perform_in_browser(:desktop) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
      choose(t('doc_auth.forms.id_type_preference.passport'))
      click_on t('forms.buttons.continue')
      expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
    end
  end

  it 'choose id type screen before doc capture in hybrid flow and proceeds after state id select',
     js: true do
    perform_in_browser(:desktop) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      expect(page).to have_current_path(idv_hybrid_mobile_choose_id_type_url)
      choose(t('doc_auth.forms.id_type_preference.drivers_license'))
      click_on t('forms.buttons.continue')
      expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
    end
  end
end
