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

  def current_session_uuid
    Capybara.current_session.driver.browser.manage.cookie_named('_upaya_session')[:value]
  end

  def session(session_uuid)
    config = Rails.application.config
    session_store = config.session_store.new({}, config.session_options)
    session_store.send(:load_session_from_redis, session_uuid) || {}
  end

  it 'proofs and hands off to mobile', js: true do
    sms_link = nil
    expect(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      sms_link = config[:link]
      impl.call(config)
    end

    perform_in_browser(:one) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_send_link_step
      fill_in :doc_auth_phone, with: '415-555-0199'
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end

    expect(sms_link).to be_present

    perform_in_browser(:two) do
      visit sms_link
      attach_and_submit_images
      expect(page).to have_text(t('doc_auth.instructions.switch_back'))
    end

    sleep 100
  end
end
