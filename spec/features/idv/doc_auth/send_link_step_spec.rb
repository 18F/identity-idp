require 'rails_helper'

feature 'doc auth send link step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    TwilioService::Utils.telephony_service = FakeSms
    enable_doc_auth
    complete_doc_auth_steps_before_send_link_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content(t('doc_auth.headings.take_picture'))
  end

  it 'proceeds to the next page with valid info' do
    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  it 'does not proceed to the next page with invalid info' do
    fill_in :doc_auth_phone, with: ''
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
  end

  it 'does not proceed if Twilio raises a RestError' do
    generic_exception = Twilio::REST::RestError.new(
      '', FakeTwilioErrorResponse.new(123)
    )
    allow(SmsDocAuthLinkJob).to receive(:perform_now).and_raise(generic_exception)
    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content t('errors.messages.invalid_phone_number')
  end

  it 'does not proceed if Twilio raises a VerifyError' do
    generic_exception = PhoneVerification::VerifyError.new(
      code: 60_033,
      message: 'error',
      status: 400,
      response:  '{"error_code":"60004"}',
    )
    allow(SmsDocAuthLinkJob).to receive(:perform_now).and_raise(generic_exception)
    fill_in :doc_auth_phone, with: '415-555-0199'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_send_link_step)
    expect(page).to have_content t('errors.messages.invalid_phone_number')
  end
end
