require 'rails_helper'

RSpec.describe 'recreating the LG-13472 bug' do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper
  include DocAuthHelper
  include IdvHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
  end

  it 'reproduces the bug', js: true, allowed_extra_analytics: [:*] do
    user = nil

    perform_in_browser(:desktop) do
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
      clear_and_fill_in(:doc_auth_phone, '415-555-0199')
      click_send_link
    end

    perform_in_browser(:mobile) do
      visit @sms_link

      mock_doc_auth_attention_with_barcode
      attach_and_submit_images
      click_button t('in_person_proofing.body.cta.button')

      # prepare page
      expect(page).to(have_content(t('in_person_proofing.body.prepare.verify_step_about')))
      click_idv_continue
      # location page
      expect(page).to have_content(t('in_person_proofing.headings.po_search.location'))
      complete_location_step

      # switch back page
      expect(page).to have_content(t('in_person_proofing.headings.switch_back'))
    end

    perform_in_browser(:desktop) do
      # Polling is disabled so we do not redirect to the next step automatically
      click_idv_continue
      # We are redirected to the SSN step for some reason
      complete_ssn_step
      complete_verify_step
    end
  end
end
