require 'rails_helper'

describe 'Hybrid Flow' do
  include IdvHelper
  include DocAuthHelper

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).and_return(true)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
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
      complete_doc_auth_steps_before_send_link_step
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end

    expect(@sms_link).to be_present

    perform_in_browser(:mobile) do
      visit @sms_link
      attach_and_submit_images
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
    end

    perform_in_browser(:desktop) do
      expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)

      fill_out_ssn_form_ok
      click_idv_continue

      expect(page).to have_content(t('headings.verify'))
      click_idv_continue

      fill_out_phone_form_ok
      click_idv_continue
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
      complete_doc_auth_steps_before_send_link_step
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

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
      click_on t('doc_auth.buttons.use_phone')
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

      expect(page).to have_content(t('doc_auth.headings.text_message'))
    end
  end
end
