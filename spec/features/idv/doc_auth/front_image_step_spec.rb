require 'rails_helper'

feature 'doc auth front image step' do
  include IdvStepHelper
  include DocAuthHelper
  include InPersonHelper

  let(:max_attempts) { AppConfig.env.acuant_max_attempts.to_i }
  let(:user) { user_with_2fa }

  before do
    allow(FeatureManagement).to receive(:document_capture_step_enabled?).and_return(false)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_front_image_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(t('doc_auth.headings.upload_front'))
  end

  it 'displays tips and sample images' do
    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(I18n.t('doc_auth.tips.text1'))
    expect(page).to have_css('img[src*=state-id-sample-front]')
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)
    expect(IdentityDocAuth::Mock::DocAuthMockClient.last_uploaded_front_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'does not proceed to the next page with invalid info' do
    mock_general_doc_auth_client_error(:create_document)
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
  end

  it 'offers in person option on failure' do
    enable_in_person_proofing

    expect(page).to_not have_link(t('in_person_proofing.opt_in_link'),
                                  href: idv_in_person_welcome_step)

    mock_general_doc_auth_client_error(:create_document)
    attach_image
    click_idv_continue

    expect(page).to have_link(t('in_person_proofing.opt_in_link'),
                              href: idv_in_person_welcome_step)
  end

  it 'throttles calls to acuant and allows retry after the attempt window' do
    allow(AppConfig.env).to receive(:acuant_max_attempts).and_return(max_attempts)
    max_attempts.times do
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
      click_on t('doc_auth.buttons.start_over')
      complete_doc_auth_steps_before_front_image_step
    end

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_throttled_path)

    Timecop.travel(AppConfig.env.acuant_attempt_window_in_minutes.to_i.minutes.from_now) do
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_front_image_step
      attach_image
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_back_image_step)
    end
  end

  it 'catches network connection errors on post_front_image' do
    IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :post_front_image,
      response: IdentityDocAuth::Response.new(
        success: false,
        errors: { network: I18n.t('errors.doc_auth.acuant_network_error') },
      ),
    )

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
  end
end
