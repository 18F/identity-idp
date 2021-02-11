require 'rails_helper'

describe 'Hybrid Flow' do
  include IdvHelper
  include DocAuthHelper

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
    allow(AppConfig.env).to receive(:doc_auth_enable_presigned_s3_urls).and_return('true')
    allow(AppConfig.env).to receive(:document_capture_async_uploads_enabled).and_return('true')
    allow(LoginGov::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
  end

  it 'proofs and hands off to mobile', js: true do
    user = nil
    sms_link = nil

    expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      sms_link = config[:link]
      impl.call(config)
    end

    perform_in_browser(:desktop) do
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_send_link_step
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end

    expect(sms_link).to be_present

    perform_in_browser(:mobile) do
      visit sms_link
      attach_and_submit_images
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)

      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_content(t('doc_auth.headings.verify'))
      click_idv_continue

      fill_out_phone_form_mfa_phone(user)
      click_idv_continue

      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_idv_continue

      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(account_path)
      expect(page).to have_content(t('headings.account.verified_account'))
    end
  end
end
