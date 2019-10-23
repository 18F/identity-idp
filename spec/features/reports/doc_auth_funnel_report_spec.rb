require 'rails_helper'

feature 'Doc Auth Funnel report' do
  include IdvStepHelper
  include DocAuthHelper

  let(:subject) { Db::DocAuthLog::DocAuthFunnelSummaryStats }
  let(:user) { create(:user, :signed_up) }
  let(:user2) { create(:user, :signed_up) }
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
  let(:doc_success_funnel) do
    {
      'back_image_error_count_average' => 0.0,
      'back_image_submit_count_average' => 1.0,
      'back_image_view_count_average' => 1.0,
      'back_image_view_percent' => 100.0,
      'capture_complete_view_count_average' => 0.0,
      'capture_complete_view_percent' => 0.0,
      'capture_mobile_back_image_view_count_average' => 0.0,
      'capture_mobile_back_image_view_percent' => 0.0,
      'capture_mobile_back_image_error_count_average' => 0.0,
      'capture_mobile_back_image_submit_count_average' => 0.0,
      'doc_success_view_count_average' => 1.0,
      'doc_success_view_percent' => 100.0,
      'email_sent_view_count_average' => 0.0,
      'email_sent_view_percent' => 0.0,
      'encrypt_view_count_average' => 0.0,
      'encrypt_view_percent' => 0.0,
      'front_image_error_count_average' => 0.0,
      'front_image_submit_count_average' => 1.0,
      'front_image_view_count_average' => 1.0,
      'front_image_view_percent' => 100.0,
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
      'send_link_view_count_average' => 0.0,
      'send_link_view_percent' => 0.0,
      'ssn_view_count_average' => 1.0,
      'ssn_view_percent' => 100.0,
      'upload_view_count_average' => 1.0,
      'upload_view_percent' => 100.0,
      'usps_address_view_count_average' => 0.0,
      'usps_address_view_percent' => 0.0,
      'usps_letter_sent_submit_count_average' => 0.0,
      'usps_letter_sent_error_count_average' => 0.0,
      'verified_view_count_average' => 0.0,
      'verified_view_percent' => 0.0,
      'verify_error_count_average' => 0.0,
      'verify_phone_view_count_average' => 0.0,
      'verify_phone_view_percent' => 0.0,
      'verify_submit_count_average' => 1.0,
      'verify_view_count_average' => 1.0,
      'verify_view_percent' => 100.0,
      'welcome_view_count_average' => 1.0,
      'welcome_view_percent' => 100.0,
    }
  end

  it 'works for no records' do
    expect(subject.new.call).to eq({})
  end

  it 'works for one flow' do
    complete_doc_auth_steps_before_doc_success_step(user)

    expect(subject.new.call).to eq(doc_success_funnel.merge(summary1))

    Funnel::DocAuth::ResetSteps.call(user.id)
    expect(subject.new.call).to_not eq(doc_success_funnel.merge(summary1))
  end

  it 'works for two flows' do
    complete_doc_auth_steps_before_doc_success_step(user)
    complete_doc_auth_steps_before_doc_success_step(user2)

    expect(subject.new.call).to eq(doc_success_funnel.merge(summary2))
  end
end
