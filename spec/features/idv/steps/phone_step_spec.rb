require 'rails_helper'

RSpec.feature 'idv phone step', :js do
  include IdvStepHelper
  include IdvHelper

  let(:user) { user_with_2fa }
  let(:gpo_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:enable_usps_verification).and_return(gpo_enabled)
  end

  context 'defaults on page load' do
    before do
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)
    end

    it 'selects sms delivery option by default' do
      expect(page).to have_checked_field(
        t('two_factor_authentication.otp_delivery_preference.sms'), visible: false
      )
    end

    it 'displays the success banner as a flash message' do
      expect(page).to have_content(t('doc_auth.forms.doc_success'))
    end
  end

  context 'with valid information' do
    it 'redirects to the otp confirmation step when the phone matches the 2fa phone number' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code

      expect(page).to have_content(t('titles.idv.enter_one_time_code', app_name: APP_NAME))
      expect(page).to have_current_path(idv_otp_verification_path)
    end
  end

  context 'with invalid form information' do
    it 'displays error message if no phone number is entered' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_in('idv_phone_form_phone', with: '') # clear the pre-populated phone number
      click_idv_send_security_code
      expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('errors.messages.phone_required'))
    end

    it 'displays error message if an invalid phone number is entered' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_in :idv_phone_form_phone, with: '578190'
      click_idv_send_security_code
      expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('errors.messages.invalid_phone_number.us'))
    end
  end

  context 'after submitting valid information' do
    it 'is re-entrant before confirming OTP' do
      first_phone_number = '7032231234'
      second_phone_number = '7037897890'

      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_ok(first_phone_number)
      click_idv_send_security_code

      expect(page).to have_content('+1 703-223-1234')

      click_link t('forms.two_factor.try_again')

      expect(page).to have_content(t('titles.idv.phone'))
      expect(page).to have_current_path(idv_phone_path(step: 'phone_otp_verification'))

      fill_out_phone_form_ok('') # clear field
      fill_out_phone_form_ok(second_phone_number)
      click_idv_otp_delivery_method_sms
      click_idv_send_security_code

      expect(page).to have_current_path(idv_otp_verification_path)
      expect(page).to have_content(t('titles.idv.enter_one_time_code'))
      expect(page).to have_content('+1 703-789-7890')
    end

    it 'is not re-entrant after confirming OTP' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)
      fill_out_phone_form_ok
      click_idv_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      visit idv_phone_path
      expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
      expect(page).to have_current_path(idv_review_path)

      fill_in 'Password', with: user_password
      click_continue

      # Currently this byasses the confirmation step since that is only
      # accessible once
      visit idv_phone_path
      expect(page).to_not have_current_path(idv_phone_path)
    end
  end

  it 'does not allow the user to advance without completing' do
    start_idv_from_sp
    complete_idv_steps_before_phone_step

    # Try to skip ahead to review step
    visit idv_review_path

    expect(page).to have_current_path(idv_phone_path)
  end

  it 'requires the user to complete the doc auth before completing' do
    start_idv_from_sp
    sign_in_and_2fa_user(user_with_2fa)
    # Try to advance ahead to the phone step
    visit idv_phone_path

    # Expect to land on doc auth
    expect(page).to have_content(t('doc_auth.headings.welcome'))
    expect(page).to have_current_path(idv_welcome_path)
  end

  it 'allows resubmitting form' do
    start_idv_from_sp
    complete_idv_steps_before_phone_step(user)
    allow(DocumentCaptureSession).to receive(:find_by).and_return(nil)
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_send_security_code

    expect(page).to have_content(t('idv.failure.timeout'))
    expect(page).to_not have_content(t('doc_auth.forms.doc_success'))
    expect(page).to have_current_path(idv_phone_path)
    allow(DocumentCaptureSession).to receive(:find_by).and_call_original
    click_idv_send_security_code
    expect(page).to have_current_path(idv_otp_verification_path)
  end

  context "when the user's information cannot be verified" do
    it 'reports the number the user entered' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_fail
      click_idv_send_security_code

      expect(page).to have_content(t('idv.failure.phone.warning.heading'))
      expect(page).to have_content('+1 703-555-5555')
    end

    it 'goes to the cancel page when cancel link is clicked' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_fail
      click_idv_send_security_code
      click_on t('links.cancel')

      expect(page).to have_current_path(idv_cancel_path(step: 'phone'))
    end

    it 'links to verify by mail, from which user can return back to the warning screen' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_fail
      click_idv_send_security_code

      expect(page).to have_content(t('idv.failure.phone.warning.heading'))

      click_on t('idv.failure.phone.warning.gpo.button')
      expect(page).to have_content(t('idv.titles.mail.verify'))

      click_doc_auth_back_link
      expect(page).to have_content(t('idv.failure.phone.warning.heading'))
    end

    it 'does not render the link to proof by mail if proofing by mail is disabled' do
      allow(FeatureManagement).to receive(:gpo_verification_enabled?).and_return(false)

      start_idv_from_sp
      complete_idv_steps_before_phone_step

      4.times do
        fill_out_phone_form_fail
        click_idv_send_security_code

        expect(page).to have_content(t('idv.failure.phone.warning.heading'))
        expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

        click_on t('idv.failure.phone.warning.try_again_button')
      end

      fill_out_phone_form_fail
      click_idv_send_security_code

      expect(page).to have_content(t('idv.troubleshooting.headings.need_assistance'))
      expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'when the IdV background job fails' do
    it_behaves_like 'failed idv phone job'
  end

  context 'after the max number of attempts' do
    it_behaves_like 'verification step max attempts', :phone
    it_behaves_like 'verification step max attempts', :phone, :oidc
    it_behaves_like 'verification step max attempts', :phone, :saml
  end

  context 'when the user is rate-limited' do
    before do
      start_idv_from_sp
      complete_idv_steps_before_step(:phone, user)
    end

    around do |ex|
      freeze_time { ex.run }
    end

    before do
      (RateLimiter.max_attempts(:proof_address) - 1).times do
        fill_out_phone_form_fail
        click_idv_continue_for_step(:phone)
        click_on t('idv.failure.phone.warning.try_again_button')
      end
      click_idv_continue_for_step(:phone)
    end

    it 'still lets them access the GPO flow and return to the error' do
      click_on t('idv.failure.phone.rate_limited.gpo.button')
      expect(page).to have_content(t('idv.titles.mail.verify'))
      click_doc_auth_back_link
      expect(page).to have_content(t('idv.failure.phone.rate_limited.heading'))
    end

    context 'GPO is disabled' do
      let(:gpo_enabled) { false }

      it 'does not link out to GPO flow' do
        expect(page).not_to have_content(t('idv.failure.phone.rate_limited.gpo.prompt'))
        expect(page).not_to have_content(t('idv.failure.phone.rate_limited.gpo.button'))
      end
    end
  end
end
