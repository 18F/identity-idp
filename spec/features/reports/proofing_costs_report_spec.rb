require 'rails_helper'

feature 'Proofing Costs report' do
  include IdvStepHelper
  include DocAuthHelper

  let(:report) { JSON.parse(Reports::ProofingCostsReport.new.call) }
  let(:user) { create(:user, :signed_up) }
  let(:user2) { create(:user, :signed_up) }
  let(:summary1) do
    {
      'total_proofing_costs_users_count' => 1,
    }
  end
  let(:summary2) do
    {
      'total_proofing_costs_users_count' => 2,
    }
  end
  let(:doc_success_funnel) do
    {
      'acuant_front_image_count_average' => 1.0,
      'acuant_back_image_count_average' => 1.0,
      'acuant_result_count_average' => 0.0,
      'aamva_count_average' => 1.0,
      'lexis_nexis_resolution_count_average' => 1.0,
      'gpo_letter_count_average' => 0.0,
      'lexis_nexis_address_count_average' => 0.0,
      'phone_otp_count_average' => 0.0,
    }
  end

  it 'works for no records' do
    expect(report).to eq({})
  end

  it 'works for one flow' do
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_doc_success_step

    expect(report).to eq(doc_success_funnel.merge(summary1))
  end

  it 'works for one flow that does the selfie check' do
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')
    allow(Figaro.env).to receive(:acuant_sdk_document_capture_enabled).and_return('true')
    allow(Figaro.env).to receive(:document_capture_step_enabled).and_return('true')

    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_document_capture_step
    attach_images
    click_idv_continue

    expect(report).to include('acuant_result_count_average' => 1.0)
  end

  it 'works for two flows' do
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_doc_success_step
    sign_in_and_2fa_user(user2)
    complete_doc_auth_steps_before_doc_success_step

    expect(report).to eq(doc_success_funnel.merge(summary2))
  end
end
