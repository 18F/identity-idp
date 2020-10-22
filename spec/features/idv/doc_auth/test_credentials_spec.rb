require 'rails_helper'

feature 'doc auth test credentials' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
  end

  it 'allows proofing with test credentials' do
    complete_doc_auth_steps_before_front_image_step

    upload_test_credentials_and_continue

    expect(page).to have_current_path(idv_doc_auth_back_image_step)

    upload_test_credentials_and_continue

    expect(page).to have_current_path(idv_doc_auth_ssn_step)

    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_content('Jane')
  end

  it 'does not initalize a acuant mock if the simulator is not enabled' do
    allow(Figaro.env).to receive(:doc_auth_vendor).and_return('acuant')

    simulated_client = IdentityDocAuth::Mock::DocAuthMockClient.new
    allow(IdentityDocAuth::Acuant::AcuantClient).to receive(:new).and_return(simulated_client)

    expect(IdentityDocAuth::Mock::DocAuthMockClient).to_not receive(:new)

    complete_all_doc_auth_steps
  end

  it 'triggers an error if the test credentials have a friendly error' do
    complete_doc_auth_steps_before_back_image_step

    attach_file 'doc_auth_image', 'spec/fixtures/ial2_test_credential_forces_error.yml'
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_front_image_step)
    expect(page).to have_content(I18n.t('friendly_errors.doc_auth.barcode_could_not_be_read'))
  end

  context 'when the app is using the acuant simulator config' do
    before do
      allow(Figaro.env).to receive(:doc_auth_vendor).and_return(nil)
    end

    it 'uses the mock vendor when acuant_simulator is true' do
      allow(Figaro.env).to receive(:acuant_simulator).and_return('true')

      expect(IdentityDocAuth::Acuant::AcuantClient).to_not receive(:new)

      complete_all_doc_auth_steps
    end

    it 'uses the acuant vendor when acuant_simulator is not true' do
      allow(Figaro.env).to receive(:acuant_simulator).and_return('false')

      simulated_client = IdentityDocAuth::Mock::DocAuthMockClient.new
      allow(IdentityDocAuth::Acuant::AcuantClient).to receive(:new).and_return(simulated_client)

      expect(IdentityDocAuth::Mock::DocAuthMockClient).to_not receive(:new)

      complete_all_doc_auth_steps
    end
  end

  def upload_test_credentials_and_continue
    attach_file 'doc_auth_image', 'spec/fixtures/ial2_test_credential.yml'
    click_idv_continue
  end
end
