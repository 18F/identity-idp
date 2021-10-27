require 'rails_helper'

feature 'doc auth verify step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:skip_step_completion) { false }
  let(:max_attempts) { idv_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:user) { create(:user, :signed_up) }
  before do
    unless skip_step_completion
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_verify_step
    end
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'masks the ssn' do
    expect(page).to have_text('6**-**-***4')
    expect(page.find('.masked-text__text', text: '666-66-1234')).
      to match_css('.display-none').or have_ancestor('.display-none')
  end

  it 'proceeds to the next page upon confirmation' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)

    click_idv_continue

    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
    user = User.first
    expect(user.proofing_component.resolution_check).to eq('lexis_nexis')
    expect(user.proofing_component.source_check).to eq('aamva')
    expect(DocAuthLog.find_by(user_id: user.id).aamva).to eq(true)
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth optional verify_wait submitted',
      address_edited: false,
    )
  end

  it 'proceeds to address page prepopulated with defaults if the user clicks change address' do
    click_link t('doc_auth.buttons.change_address')

    expect(page).to have_current_path(idv_address_path)
    expect(page).to have_selector("input[value='1 FAKE RD']")
    expect(page).to have_selector("input[value='GREAT FALLS']")
    expect(page).to have_selector("input[value='59010']")
  end

  it 'tracks when the user edits their address' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)

    click_link t('doc_auth.buttons.change_address')
    fill_out_address_form_ok
    click_idv_continue # address form

    click_idv_continue

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth optional verify_wait submitted',
      address_edited: true,
    )
  end

  it 'proceeds to the ssn page if the user clicks change ssn and allows user to go back' do
    click_button t('doc_auth.buttons.change_ssn')

    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(page).to have_content(t('doc_auth.headings.ssn_update'))

    click_button t('forms.buttons.back')
    expect(page).to have_current_path(idv_doc_auth_verify_step)
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

    expect(page).to have_current_path(idv_session_errors_warning_path)
  end

  it 'throttles resolution and continues when it expires' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
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
    expect(fake_analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: :idv_resolution,
      step_name: Idv::Steps::VerifyWaitStepShow,
    )

    travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(page).to have_current_path(idv_phone_path)
    end
  end

  it 'throttles dup ssn' do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
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
    expect(fake_analytics).to have_logged_event(
      Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
      throttle_type: :idv_resolution,
      step_name: Idv::Steps::VerifyWaitStepShow,
    )
  end

  it 'shows the step indicator' do
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.verify_info'),
    )
  end

  context 'when the user lives in an AAMVA supported state' do
    it 'performs a resolution and state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof_resolution).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      # rubocop:disable Layout/LineLength
      stub_const(
        'Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS',
        Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS +
          [DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC[:state_id_jurisdiction]],
      )
      # rubocop:enable Layout/LineLength

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof_resolution).with(
        anything,
        should_proof_state_id: true,
        document_expired: nil,
        trace_id: anything,
      )
    end
  end

  context 'when the user does not live in an AAMVA supported state' do
    it 'does not perform the state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof_resolution).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      # rubocop:disable Layout/LineLength
      stub_const(
        'Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS',
        Idv::Steps::VerifyBaseStep::AAMVA_SUPPORTED_JURISDICTIONS -
          [DocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC[:state_id_jurisdiction]],
      )
      # rubocop:enable Layout/LineLength

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof_resolution).with(
        anything,
        should_proof_state_id: false,
        document_expired: nil,
        trace_id: anything,
      )
      expect(DocAuthLog.find_by(user_id: user.id).aamva).to be_nil
    end
  end

  context 'when the SP is in the AAMVA banlist' do
    it 'does not perform the state ID check' do
      agent = instance_double(Idv::Agent)
      allow(Idv::Agent).to receive(:new).and_return(agent)
      allow(agent).to receive(:proof_resolution).and_return(
        success: true, errors: {}, context: { stages: [] },
      )

      allow(IdentityConfig.store).to receive(:aamva_sp_banlist_issuers).
        and_return('["urn:gov:gsa:openidconnect:sp:server"]')

      visit_idp_from_sp_with_ial1(:oidc)
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step
      click_idv_continue

      expect(agent).to have_received(:proof_resolution).with(
        anything,
        should_proof_state_id: false,
        document_expired: nil,
        trace_id: anything,
      )
    end
  end

  context 'async timed out' do
    it 'allows resubmitting form' do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_verify_step

      allow_any_instance_of(ApplicationController).
          to receive(:analytics).and_return(fake_analytics)

      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)

      click_continue
      # FLAKE: this errors due to some race condition, likely due to polling in the browser
      expect(fake_analytics).to have_logged_event(Analytics::PROOFING_RESOLUTION_TIMEOUT, {})
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_doc_auth_verify_step)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_continue
      expect(page).to have_current_path(idv_phone_path)
    end
  end

  context 'javascript enabled', js: true do
    around do |example|
      # Adjust the wait time to give the frontend time to poll for results.
      Capybara.using_wait_time(5) do
        example.run
      end
    end

    it 'can toggle viewing the ssn' do
      expect(page).to have_text('6**-**-***4')
      expect(page).not_to have_text('666-66-1234')

      check t('forms.ssn.show')
      expect(page).to have_text('666-66-1234')
      expect(page).not_to have_text('6**-**-***4')

      uncheck t('forms.ssn.show')
      expect(page).to have_text('6**-**-***4')
      expect(page).not_to have_text('666-66-1234')
    end

    it 'proceeds to the next page upon confirmation' do
      click_idv_continue

      expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('doc_auth.forms.doc_success'))
    end

    context 'resolution failure' do
      let(:skip_step_completion) { true }

      it 'does not proceed to the next page' do
        sign_in_and_2fa_user
        complete_doc_auth_steps_before_ssn_step
        fill_out_ssn_form_with_ssn_that_fails_resolution
        click_idv_continue
        click_idv_continue

        expect(page).to have_current_path(idv_session_errors_warning_path)

        click_on t('idv.failure.button.warning')

        expect(page).to have_current_path(idv_doc_auth_verify_step)
      end
    end

    context 'async timed out' do
      it 'allows resubmitting form' do
        allow(DocumentCaptureSession).to receive(:find_by).
          and_return(nil)
        allow_any_instance_of(ApplicationController).
          to receive(:analytics).and_return(fake_analytics)

        click_continue
        # FLAKE: this errors due to some race condition, likely due to polling in the browser
        # expect(fake_analytics).to have_logged_event(Analytics::PROOFING_RESOLUTION_TIMEOUT, {})
        expect(page).to have_content(t('idv.failure.timeout'))
        expect(page).to have_current_path(idv_doc_auth_verify_step)
        allow(DocumentCaptureSession).to receive(:find_by).and_call_original
        click_continue
        expect(page).to have_current_path(idv_phone_path)
      end
    end
  end
end
