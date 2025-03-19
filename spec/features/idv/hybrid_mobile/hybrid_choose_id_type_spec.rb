require 'rails_helper'

RSpec.feature 'mobile hybrid flow choose id type', :js, :allow_net_connect_on_start do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper
  include AbTestsHelper

  let(:phone_number) { '415-555-0199' }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
    stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
      .to_return({ status: 200, body: { status: 'UP' }.to_json })
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
    reload_ab_tests
    sign_in_and_2fa_user
  end

  after do
    reload_ab_tests
  end

  it 'proofs and hands off to mobile', js: true do
    perform_in_browser(:desktop) do
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
