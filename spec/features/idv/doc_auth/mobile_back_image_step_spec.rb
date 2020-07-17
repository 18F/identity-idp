require 'rails_helper'

feature 'doc auth mobile back image step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_mobile_back_image_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_mobile_back_image_step)
    expect(page).to have_content(t('doc_auth.headings.take_pic_back'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(DocAuthMock::DocAuthMockClient.last_uploaded_back_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'proceeds to the next page if the user does not have a phone' do
    user = create(:user, :with_authentication_app, :with_piv_or_cac)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_mobile_back_image_step
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not proceed to the next page if the image upload fails' do
    DocAuthMock::DocAuthMockClient.mock_response!(
      method: :post_back_image,
      response: Acuant::Response.new(
        success: false,
        errors: [I18n.t('errors.doc_auth.acuant_network_error')],
      ),
    )

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_mobile_back_image_step)
    expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
  end

  it 'sends the user back to the front image step if the document cannot be verified' do
    mock_general_doc_auth_client_error(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_mobile_front_image_step)
    expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
    expect(page).to have_content(strip_tags(I18n.t('errors.doc_auth.general_info'))[0..32])
  end

  it 'does not attempt to verify the document if selfie checking is enabled' do
    allow(Figaro.env).to receive(:liveness_checking_enabled).and_return('true')

    mock_client = DocAuthMock::DocAuthMockClient.new
    allow(DocAuthMock::DocAuthMockClient).to receive(:new).and_return(mock_client)

    expect(mock_client).to_not receive(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_selfie_step)
  end
end
