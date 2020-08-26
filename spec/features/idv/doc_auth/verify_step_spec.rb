require 'rails_helper'

feature 'doc auth verify step' do
  include IdvStepHelper
  include DocAuthHelper
  include InPersonHelper

  let(:max_attempts) { idv_max_attempts }
  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'proceeds to the next page upon confirmation' do
    click_idv_continue

    expect(page).to have_current_path(idv_doc_auth_success_step)
    user = User.first
    expect(user.proofing_component.resolution_check).to eq('lexis_nexis')
    expect(user.proofing_component.source_check).to eq('aamva')
  end

  it 'proceeds to address page prepopulated with defaults if the user clicks change address' do
    click_link t('doc_auth.buttons.change_address')

    expect(page).to have_current_path(idv_address_path)
    expect(page).to have_selector("input[value='1 FAKE RD']")
    expect(page).to have_selector("input[value='GREAT FALLS']")
    expect(page).to have_selector("input[value='59010']")
  end

  it 'proceeds to the ssn page if the user clicks change ssn' do
    click_button t('doc_auth.buttons.change_ssn')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_warning_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not proceed to the next page if resolution raises an exception' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_raises_exception
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_errors_exception_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_doc_auth_verify_step)
  end

  it 'does not proceed to the next page if ssn is a duplicate' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    enable_in_person_proofing
    expect(page).to have_current_path(idv_session_errors_warning_path)
    expect(page).to_not have_link(t('in_person_proofing.opt_in_link'),
                                  href: idv_in_person_welcome_step)
  end

  it 'has a link to proof in person' do
    enable_in_person_proofing
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_link(t('in_person_proofing.opt_in_link'),
                              href: idv_in_person_welcome_step)
  end

  it 'throttles resolution and continues when it expires' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_errors_warning_path)
      visit idv_doc_auth_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_errors_failure_path)

    Timecop.travel(Figaro.env.idv_attempt_window_in_hours.to_i.hours.from_now) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(page).to have_current_path(idv_doc_auth_success_step)
    end
  end

  it 'throttles dup ssn' do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_errors_warning_path)
      visit idv_doc_auth_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_errors_failure_path)
  end

  context 'when the user lives in an AAMVA supported state' do
    it 'performs a resolution and state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      stub_const(
        'Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS',
        Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS +
          [DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC[:state_id_jurisdiction]],
      )

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof).with(:resolution, :state_id)
    end
  end

  context 'when the user lives in an AAMVA unsupported state' do
    it 'does not perform the state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      stub_const(
        'Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS',
        Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS -
          [DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC[:state_id_jurisdiction]],
      )

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof).with(:resolution)
    end
  end

  context 'when the SP is in the AAMVA banlist' do
    it 'does not perform the state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      allow(Figaro.env).to receive(:aamva_sp_banlist_issuers).
        and_return('["urn:gov:gsa:openidconnect:sp:server"]')

      visit_idp_from_sp_with_ial1(:oidc)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof).with(:resolution)
    end
  end
end
