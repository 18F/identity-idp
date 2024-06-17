require 'rails_helper'

RSpec.feature 'verify_info step and verify_info_concern', :js, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:user) { user_with_2fa }

  # values from Idp::Constants::MOCK_IDV_APPLICANT
  let(:fake_pii_details) do
    {
      document_state: 'MT',
      document_number: '1111111111111',
      document_issued: '2019-12-31',
      document_expiration: '2099-12-31',
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      date_of_birth: '1938-10-06',
      address: '1 FAKE RD',
    }
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_ssn_step
  end

  context 'with good ssn' do
    before do
      fill_out_ssn_form_ok
      click_idv_continue
    end

    it 'allows the user to enter in a new address and displays updated info' do
      click_link t('idv.buttons.change_address_label')
      fill_in 'idv_form_zipcode', with: '12345'
      fill_in 'idv_form_address2', with: 'Apt 3E'

      click_button t('forms.buttons.submit.update')

      expect(page).to have_current_path(idv_verify_info_path)

      expect(page).to have_content('12345')
      expect(page).to have_content('Apt 3E')

      complete_verify_step

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth verify proofing results',
        hash_including(
          address_edited: true,
          address_line2_present: true,
          analytics_id: 'Doc Auth',
        ),
      )
    end

    it 'allows the user to enter in a new ssn and displays updated info' do
      click_link t('idv.buttons.change_ssn_label')

      expect(page).to have_current_path(idv_ssn_path)
      expect(page).to_not have_content(t('doc_auth.headings.capture_complete'))
      expect(
        find_field(t('idv.form.ssn_label')).value,
      ).to eq(DocAuthHelper::GOOD_SSN.gsub(/\D/, ''))

      fill_in t('idv.form.ssn_label'), with: '900456789'
      click_button t('forms.buttons.submit.update')

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth redo_ssn submitted',
      )

      expect(page).to have_current_path(idv_verify_info_path)

      expect(page).to have_text('9**-**-***9')
      check t('forms.ssn.show')
      expect(page).to have_text('900-45-6789')
    end

    it 'logs analytics event on submit' do
      complete_verify_step

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth verify proofing results',
        hash_including(address_edited: false, address_line2_present: false),
      )
    end
  end

  it 'does not proceed to the next page if resolution fails' do
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    complete_verify_step

    expect(page).to have_current_path(idv_session_errors_warning_path)
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_verify_info_path)
  end

  it 'does not proceed to the next page if resolution raises an exception' do
    fill_out_ssn_form_with_ssn_that_raises_exception

    click_idv_continue
    complete_verify_step

    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth exception visited',
      step_name: 'verify_info',
      remaining_submit_attempts: 5,
    )
    expect(page).to have_current_path(idv_session_errors_exception_path)

    click_on t('idv.failure.button.warning')

    expect(page).to have_current_path(idv_verify_info_path)
  end

  context 'resolution rate limiting' do
    let(:max_resolution_attempts) { 3 }
    before do
      allow(IdentityConfig.store).to receive(:idv_max_attempts).
        and_return(max_resolution_attempts)

      fill_out_ssn_form_with_ssn_that_fails_resolution
      click_idv_continue
    end

    # proof_ssn_max_attempts is 10, vs 5 for resolution, so it doesn't get triggered
    it 'rate limits resolution and continues when it expires' do
      (max_resolution_attempts - 2).times do
        complete_verify_step
        expect(page).to have_current_path(idv_session_errors_warning_path)
        click_try_again
      end

      # Check that last attempt shows correct warning text
      complete_verify_step
      expect(page).to have_current_path(idv_session_errors_warning_path)
      expect(page).to have_content(
        strip_tags(
          t('idv.failure.attempts_html.one'),
        ),
      )
      click_try_again

      complete_verify_step
      expect(page).to have_current_path(idv_session_errors_failure_path)
      expect(page).not_to have_css('.step-indicator__step--current', text: text, wait: 5)
      expect(fake_analytics).to have_logged_event(
        'Rate Limit Reached',
        limiter_type: :idv_resolution,
        step_name: 'verify_info',
      )

      visit idv_verify_info_url
      expect(page).to have_current_path(idv_session_errors_failure_path)

      # Manual expiration is needed because Redis timestamp doesn't always match ruby timestamp
      RateLimiter.new(user: user, rate_limit_type: :idv_resolution).reset!
      travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_verify_step
        complete_verify_step

        expect(page).to have_current_path(idv_phone_path)
        expect(RateLimiter.new(user: user, rate_limit_type: :idv_resolution)).to_not be_limited
      end
    end

    it 'allows user to cancel identify verification' do
      click_link t('links.cancel')
      expect(page).to have_current_path(idv_cancel_path(step: 'verify'))
    end
  end

  context 'ssn rate limiting' do
    # Simulates someone trying same SSN with second account
    let(:max_resolution_attempts) { 4 }
    let(:max_ssn_attempts) { 3 }

    before do
      allow(IdentityConfig.store).to receive(:idv_max_attempts).
        and_return(max_resolution_attempts)

      allow(IdentityConfig.store).to receive(:proof_ssn_max_attempts).
        and_return(max_ssn_attempts)

      fill_out_ssn_form_with_ssn_that_fails_resolution
      click_idv_continue
      (max_ssn_attempts - 1).times do
        complete_verify_step
        expect(page).to have_current_path(idv_session_errors_warning_path)
        click_try_again
      end
    end

    it 'rate limits ssn and continues when it expires' do
      complete_verify_step
      expect(page).to have_current_path(idv_session_errors_ssn_failure_path)
      expect(fake_analytics).to have_logged_event(
        'Rate Limit Reached',
        limiter_type: :proof_ssn,
        step_name: 'verify_info',
      )

      visit idv_verify_info_url
      expect(page).to have_current_path(idv_session_errors_ssn_failure_path)

      # Manual expiration is needed because Redis timestamp doesn't always match ruby timestamp
      RateLimiter.new(user: user, rate_limit_type: :idv_resolution).reset!
      travel_to(IdentityConfig.store.idv_attempt_window_in_hours.hours.from_now + 1) do
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_verify_step
        complete_verify_step

        expect(page).to have_current_path(idv_phone_path)
        expect(RateLimiter.new(user: user, rate_limit_type: :idv_resolution)).to_not be_limited
      end
    end

    it 'continues to next step if ssn successful on last attempt' do
      click_link t('idv.buttons.change_ssn_label')

      expect(page).to have_current_path(idv_ssn_path)
      expect(page).to_not have_content(t('doc_auth.headings.capture_complete'))
      expect(
        find_field(t('idv.form.ssn_label')).value,
      ).not_to eq(DocAuthHelper::GOOD_SSN.gsub(/\D/, ''))

      fill_in t('idv.form.ssn_label'), with: '900456789'
      click_button t('forms.buttons.submit.update')
      complete_verify_step

      expect(page).to have_current_path(idv_phone_path)
      expect(fake_analytics).not_to have_logged_event(
        'Rate Limit Reached',
        limiter_type: :proof_ssn,
        step_name: 'verify_info',
      )
    end
  end

  context 'AAMVA' do
    let(:mock_state_id_jurisdiction) do
      [Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction]]
    end

    context 'when the user lives in an AAMVA supported state' do
      it 'performs a resolution and state ID check' do
        allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
          mock_state_id_jurisdiction,
        )
        expect_any_instance_of(Proofing::Mock::StateIdMockClient).to receive(:proof).with(
          hash_including(
            **Idp::Constants::MOCK_IDV_APPLICANT,
          ),
        ).and_call_original

        complete_ssn_step
        complete_verify_step
      end
    end

    context 'when the user does not live in an AAMVA supported state' do
      it 'does not perform the state ID check' do
        allow(IdentityConfig.store).to receive(:aamva_supported_jurisdictions).and_return(
          IdentityConfig.store.aamva_supported_jurisdictions -
            mock_state_id_jurisdiction,
        )
        expect_any_instance_of(Proofing::Mock::StateIdMockClient).to_not receive(:proof)

        complete_ssn_step
        complete_verify_step
      end
    end
  end

  context 'async missing' do
    it 'allows resubmitting form' do
      complete_ssn_step

      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)

      complete_verify_step
      expect(fake_analytics).to have_logged_event('IdV: proofing resolution result missing')
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_verify_info_path)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      complete_verify_step
      expect(page).to have_current_path(idv_phone_path)
    end
  end

  context 'async timed out' do
    it 'allows resubmitting form' do
      complete_ssn_step

      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)

      complete_verify_step
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_verify_info_path)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      complete_verify_step
      expect(page).to have_current_path(idv_phone_path)
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(OutageStatus).to receive(:any_phone_vendor_outage?).and_return(true)
      visit_idp_from_sp_with_ial2(:oidc)
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_verify_step
    end

    it 'should be at the verify step page' do
      expect(page).to have_current_path(idv_verify_info_path)
    end

    it 'redirects to the gpo page when continuing from verify info page' do
      complete_verify_step
      expect(page).to have_current_path(idv_request_letter_path)

      click_on 'Cancel'
      expect(page).to have_current_path(idv_cancel_path(step: :gpo))
    end
  end
end
