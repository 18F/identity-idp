require 'rails_helper'

RSpec.feature 'idv phone step', :js do
  include IdvStepHelper
  include IdvHelper

  let(:user) { user_with_2fa }
  let(:gpo_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:enable_usps_verification).and_return(gpo_enabled)
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
      expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
      expect(page).to have_current_path(idv_review_path)

      fill_in 'Password', with: user_password
      click_continue

      # Currently this byasses the confirmation step since that is only
      # accessible once
      visit idv_phone_path
      expect(page).to_not have_current_path(idv_phone_path)
    end
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
    before do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_fail
    end

    it 'reports the number the user entered' do
      click_idv_send_security_code

      expect(page).to have_content(t('idv.failure.phone.warning.heading'))
      expect(page).to have_content('+1 703-555-5555')
    end

    context 'resubmission after number failed verification' do
      it 'phone field is empty after invalid submission' do
        phone_field = find_field(t('two_factor_authentication.phone_label'))

        expect(phone_field.value).not_to be_empty

        click_idv_send_security_code
        click_on t('idv.failure.phone.warning.try_again_button')

        expect(page).to have_current_path(idv_phone_path)
        expect(phone_field.value).to be_empty
      end

      it 'succeeds to otp verification with valid number resubmission' do
        click_idv_send_security_code
        click_on t('idv.failure.phone.warning.try_again_button')

        expect(page).to have_current_path(idv_phone_path)

        fill_out_phone_form_ok
        click_idv_send_security_code
        expect(page).to have_current_path(idv_otp_verification_path)
      end

      context 'displays alert message if same nubmer is resubmitted' do
        context 'gpo verification is enabled' do
          it 'includes verify link' do
            click_idv_send_security_code
            click_on t('idv.failure.phone.warning.try_again_button')

            expect(page).to have_current_path(idv_phone_path)

            fill_out_phone_form_fail

            expect(page).to have_content(t('idv.messages.phone.failed_number.alert_text'))

            expect(page).to have_content(
              strip_tags(
                t(
                  'idv.messages.phone.failed_number.gpo_alert_html',
                  link_html: t('idv.messages.phone.failed_number.gpo_verify_link'),
                ),
              ),
            )

            click_idv_send_security_code
            click_on t('idv.failure.phone.warning.try_again_button')

            expect(page).to have_current_path(idv_phone_path)
          end
        end

        context 'gpo verification is disabled' do
          before do
            allow(IdentityConfig.store).to receive(:enable_usps_verification).and_return(false)
          end

          it 'does not display verify link' do
            click_idv_send_security_code
            click_on t('idv.failure.phone.warning.try_again_button')

            expect(page).to have_current_path(idv_phone_path)

            fill_out_phone_form_fail

            expect(page).to have_content(t('idv.messages.phone.failed_number.alert_text'))
            expect(page).not_to have_content(
              strip_tags(
                t(
                  'idv.messages.phone.failed_number.gpo_alert_html',
                  link_html: t('idv.messages.phone.failed_number.gpo_verify_link'),
                ),
              ),
            )
            expect(page).to have_content(
              strip_tags(
                t('idv.messages.phone.failed_number.try_again_html'),
              ),
            )

            click_idv_send_security_code
            click_on t('idv.failure.phone.warning.try_again_button')

            expect(page).to have_current_path(idv_phone_path)
          end
        end
      end
    end

    context 'phone number submission times out' do
      it 'does not display failed alert message' do
        timeout_phone_number = '7035555888'
        start_idv_from_sp
        complete_idv_steps_before_phone_step
        fill_out_phone_form_ok(timeout_phone_number)
        click_idv_send_security_code
        click_on t('idv.failure.button.warning')

        expect(page).to have_current_path(idv_phone_path)

        fill_out_phone_form_ok(timeout_phone_number)

        expect(page).not_to have_content(t('idv.messages.phone.failed_number.alert_text'))

        click_idv_send_security_code
        click_on t('idv.failure.button.warning')

        expect(page).to have_current_path(idv_phone_path)
      end
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
      fill_out_phone_form_fail
      click_idv_continue_for_step(:phone)
    end

    it 'takes them to the IdV cancel screen if they hit cancel', js: true do
      click_on 'Cancel'
      expect(current_path).to eq(idv_cancel_path)
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
        prompt_text = t('idv.failure.phone.rate_limited.option_verify_by_mail_html')
        expect(page).not_to have_content(prompt_text)
        expect(page).not_to have_content(t('idv.failure.phone.rate_limited.gpo.button'))
      end
    end
  end
end
