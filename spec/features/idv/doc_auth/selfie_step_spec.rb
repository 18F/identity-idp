require 'rails_helper'

feature 'doc auth self image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')
    @user = sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_selfie_step)
  end

  it 'proceeds to the next page and logs a cost with valid info' do
    proofing_cost = ProofingCost.find_by(user_id: @user.id)
    count = proofing_cost.acuant_result_count

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(proofing_cost.reload.acuant_result_count).to eq(count + 1)
  end

  it 'restarts doc auth if the document cannot be authenticated' do
    mock_general_doc_auth_client_error(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
  end

  it 'restarts doc auth if the selfie cannot be matched' do
    DocAuthMock::DocAuthMockClient.mock_response!(
      method: :post_selfie,
      response: Acuant::Response.new(
        success: false,
        errors: [I18n.t('errors.doc_auth.selfie')],
      ),
    )

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(t('errors.doc_auth.selfie'))
  end
end
