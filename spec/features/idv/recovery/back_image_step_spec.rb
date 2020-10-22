require 'rails_helper'

feature 'recovery back image step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }
  let(:user_no_phone) { create(:user, :with_authentication_app, :with_piv_or_cac) }
  let(:profile) { build(:profile, :active, :verified, user: user_no_phone, pii: { ssn: '1234' }) }
  let(:max_attempts) { Figaro.env.acuant_max_attempts.to_i }

  before do |example|
    select_user = example.metadata[:no_phone] ? user_no_phone : user
    sign_in_before_2fa(user)
    complete_recovery_steps_before_back_image_step(select_user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_back_image_step)
    expect(page).to have_content(t('doc_auth.headings.upload_back'))
  end

  it 'proceeds to the next page with valid info' do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_ssn_step)
  end

  it 'proceeds to the next page if the user does not have a phone', :no_phone do
    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_ssn_step)
  end

  it 'allows the use of a base64 encoded data url representation of the image' do
    attach_image_data_url
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_ssn_step)
    expect(IdentityDocAuth::Mock::DocAuthMockClient.last_uploaded_back_image).to eq(
      doc_auth_image_data_url_data,
    )
  end

  it 'does not proceed to the next page with invalid info' do
    mock_general_doc_auth_client_error(:post_back_image)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_back_image_step)
  end

  it 'does not proceed to the next page with result=2' do
    mock_general_doc_auth_client_error(:get_results)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_front_image_step)
    expect(page).to have_content(I18n.t('errors.doc_auth.general_error'))
    expect(page).to have_content(strip_tags(I18n.t('errors.doc_auth.general_info'))[0..32])
  end

  it 'throttles calls to acuant and allows account reset on the error page' do
    allow(Throttler::IsThrottledElseIncrement).to receive(:call).and_return(true)

    attach_image
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_recovery_throttled_path)
    expect(page).to have_link(t('two_factor_authentication.account_reset.reset_your_account'))
  end
end
