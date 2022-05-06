require 'rails_helper'

feature 'Doc Auth Funnel report' do
  include IdvStepHelper
  include DocAuthHelper

  let(:subject) { Db::DocAuthLog::DocAuthFunnelSummaryStats }
  let(:user) { create(:user, :signed_up) }
  let(:user2) { create(:user, :signed_up) }
  let(:issuer) { 'foo' }
  let(:summary1) do
    {
      'total_verified_users_count' => 0,
      'total_verify_attempted_users_count' => 1,
    }
  end
  let(:summary2) do
    {
      'total_verified_users_count' => 0,
      'total_verify_attempted_users_count' => 2,
    }
  end
  let(:verify_funnel) do
    {
      'back_image_error_count_average' => 0.0,
      'back_image_submit_count_average' => 0.0,
      'back_image_view_count_average' => 0.0,
      'back_image_view_percent' => 0.0,
      'capture_complete_view_count_average' => 0.0,
      'capture_complete_view_percent' => 0.0,
      'capture_mobile_back_image_view_count_average' => 0.0,
      'capture_mobile_back_image_view_percent' => 0.0,
      'capture_mobile_back_image_error_count_average' => 0.0,
      'capture_mobile_back_image_submit_count_average' => 0.0,
      'choose_method_view_count_average' => 0.0,
      'choose_method_view_percent' => 0.0,
      'document_capture_error_count_average' => 0.0,
      'document_capture_submit_count_average' => 1.0,
      'document_capture_view_count_average' => 1.0,
      'document_capture_view_percent' => 100.0,
      'email_sent_view_count_average' => 0.0,
      'email_sent_view_percent' => 0.0,
      'encrypt_view_count_average' => 0.0,
      'encrypt_view_percent' => 0.0,
      'enter_info_view_count_average' => 0.0,
      'enter_info_view_percent' => 0.0,
      'front_image_error_count_average' => 0.0,
      'front_image_submit_count_average' => 0.0,
      'front_image_view_count_average' => 0.0,
      'front_image_view_percent' => 0.0,
      'link_sent_view_count_average' => 0.0,
      'link_sent_view_percent' => 0.0,
      'mobile_back_image_view_count_average' => 0.0,
      'mobile_back_image_view_percent' => 0.0,
      'mobile_back_image_error_count_average' => 0.0,
      'mobile_back_image_submit_count_average' => 0.0,
      'mobile_front_image_view_count_average' => 0.0,
      'mobile_front_image_view_percent' => 0.0,
      'mobile_front_image_error_count_average' => 0.0,
      'mobile_front_image_submit_count_average' => 0.0,
      'present_cac_error_count_average' => 0.0,
      'present_cac_submit_count_average' => 0.0,
      'present_cac_view_count_average' => 0.0,
      'present_cac_view_percent' => 0.0,
      'selfie_error_count_average' => 0.0,
      'selfie_submit_count_average' => 0.0,
      'selfie_view_count_average' => 0.0,
      'selfie_view_percent' => 0.0,
      'send_link_view_count_average' => 0.0,
      'send_link_view_percent' => 0.0,
      'ssn_view_count_average' => 1.0,
      'ssn_view_percent' => 100.0,
      'success_view_count_average' => 0.0,
      'success_view_percent' => 0.0,
      'upload_view_count_average' => 1.0,
      'upload_view_percent' => 100.0,
      'usps_address_view_count_average' => 0.0,
      'usps_address_view_percent' => 0.0,
      'usps_letter_sent_submit_count_average' => 0.0,
      'usps_letter_sent_error_count_average' => 0.0,
      'verified_view_count_average' => 0.0,
      'verified_view_percent' => 0.0,
      'verify_error_count_average' => 0.0,
      'verify_phone_view_count_average' => 1.0,
      'verify_phone_view_percent' => 100.0,
      'verify_submit_count_average' => 1.0,
      'verify_view_count_average' => 1.0,
      'verify_view_percent' => 100.0,
      'welcome_view_count_average' => 1.0,
      'welcome_view_percent' => 100.0,
      'agreement_view_count_average' => 1.0,
      'agreement_view_percent' => 100.0,
      'verify_phone_submit_count_average' => 0.0,
      'verify_phone_submit_percent' => 0.0,
      'document_capture_submit_percent' => 100.0,
      'verify_submit_percent' => 100.0,
    }
  end

  it 'works for no records' do
    expect(subject.new.call).to eq({})
  end

  it 'works for one flow' do
    sign_in_and_2fa_user(user)
    complete_all_doc_auth_steps

    expect(subject.new.call).to eq(verify_funnel.merge(summary1))

    Funnel::DocAuth::ResetSteps.call(user.id)
    expect(subject.new.call).to_not eq(verify_funnel.merge(summary1))
  end

  it 'works for two flows' do
    sign_in_and_2fa_user(user)
    complete_all_doc_auth_steps
    sign_in_and_2fa_user(user2)
    complete_all_doc_auth_steps

    expect(subject.new.call).to eq(verify_funnel.merge(summary2))
  end

  it 'does not create a doc_auth_log entry without a welcome first' do
    Funnel::DocAuth::RegisterStep.new(user.id, issuer).call('upload', :view, true)

    expect(DocAuthLog.count).to eq(0)
  end

  it 'does create a doc_auth_log entry when a welcome is first' do
    Funnel::DocAuth::RegisterStep.new(user.id, issuer).call('welcome', :view, true)
    Funnel::DocAuth::RegisterStep.new(user.id, issuer).call('upload', :view, true)

    expect(DocAuthLog.count).to eq(1)
  end
end
