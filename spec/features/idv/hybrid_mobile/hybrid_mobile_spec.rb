require 'rails_helper'

describe 'Hybrid Flow', :allow_net_connect_on_start do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper

  let(:phone_number) { '415-555-0199' }

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
  end

  before do
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
  end

  it 'proofs and hands off to mobile', js: true do
    user = nil

    perform_in_browser(:desktop) do
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_upload_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))

      # Confirm that Continue button is not shown when polling is enabled
      expect(page).not_to have_content(t('doc_auth.buttons.continue'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link

      # Confirm app disallows jumping ahead to CaptureComplete page
      visit idv_hybrid_mobile_capture_complete_url
      expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)

      # Confirm that jumping to LinkSent page does not cause errors
      visit idv_link_sent_url
      expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)

      attach_and_submit_images

      expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      expect(page).to have_content(t('doc_auth.headings.capture_complete').tr(' ', ' '))
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

      # Confirm app disallows jumping back to DocumentCapture page
      visit idv_hybrid_mobile_document_capture_url
      expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
      expect(page).to have_current_path(idv_ssn_path)

      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_content(t('headings.verify'))
      click_idv_continue

      fill_out_phone_form_ok
      verify_phone_otp

      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_idv_continue

      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('headings.account.verified_account'))
    end
  end

  it 'shows the waiting screen correctly after cancelling from mobile and restarting', js: true do
    user = nil

    perform_in_browser(:desktop) do
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_upload_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      click_on t('links.cancel')
      click_on t('forms.buttons.cancel') # Yes, cancel
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end
  end
end
