require 'rails_helper'

feature 'idv phone step', :js do
  include IdvStepHelper
  include IdvHelper

  context 'defaults on page load' do
    it 'selects sms delivery option by default', js: true do
      user = user_with_2fa
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)
      expect(page).to have_checked_field(t('two_factor_authentication.otp_delivery_preference.sms'), visible: false)
    end
  end

  context 'with valid information' do
    # it 'allows the user to continue to the phone otp delivery selection step' do
    #   start_idv_from_sp
    #   complete_idv_steps_before_phone_step
    #   fill_out_phone_form_ok
    #   click_idv_continue

    #   expect(page).to have_content(t('idv.titles.otp_delivery_method'))
    #   expect(page).to have_current_path(idv_otp_delivery_method_path)
    # end

    it 'redirects to the otp delivery step when the phone matches the 2fa phone number', js: true do
      user = user_with_2fa
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      #click_idv_continue
      click_idv_send_security_code
      save_and_open_page
      expect(page).to have_content(t('idv.titles.otp_delivery_method', app_name: APP_NAME))
      expect(page).to have_current_path(idv_phone_path)
    end


    # I don't think we want to allow this behavior anymore
    xit 'allows a user without a phone number to continue' do
      user = create(:user, :with_authentication_app, :with_backup_code)
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      fill_out_phone_form_ok
      click_idv_continue

      expect(page).to have_content(t('idv.titles.otp_delivery_method'))
      expect(page).to have_current_path(idv_otp_delivery_method_path)

      choose_idv_otp_delivery_method_sms

      expect(page).to have_content(t('two_factor_authentication.header_text'))
      expect(page).to_not have_content(t('two_factor_authentication.totp_header_text'))
      expect(page).to_not have_content(t('two_factor_authentication.login_options_link_text'))
    end
  end


  context 'invalid form information' do
    it 'displays error message if no phone number is entered', js: true do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_in("idv_phone_form_phone", with: "") # clear the pre-populated phone number
      click_idv_send_security_code
      #expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('errors.messages.phone_required'))
    end

    it 'displays error message if an invalid phone number is entered' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_in :idv_phone_form_phone, with: '578190'
      click_idv_send_security_code
      #expect(page).to have_current_path(idv_phone_path)
      expect(page).to have_content(t('errors.messages.invalid_phone_number'))
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
      save_and_open_page
      expect(page).to have_content(t('idv.titles.session.phone'))
      expect(page).to have_current_path(idv_phone_path(step: 'phone_otp_verification'))

      fill_out_phone_form_ok("") # clear field
      fill_out_phone_form_ok(second_phone_number)
      click_idv_otp_delivery_method_sms
      click_idv_send_security_code

      expect(page).to have_content('+1 703-789-7890')
    end

    it 'is not re-entrant after confirming OTP' do
      user = user_with_2fa

      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)
      fill_out_phone_form_ok
      click_idv_continue
      choose_idv_otp_delivery_method_sms
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
    expect(page).to have_current_path(idv_doc_auth_step_path(step: :welcome))
  end

  shared_examples 'async timed out' do
    it 'allows resubmitting form' do
      user = user_with_2fa
      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      allow(DocumentCaptureSession).to receive(:find_by).and_return(nil)
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_continue
      expect(page).to have_content(t('idv.failure.timeout'))
      expect(page).to have_current_path(idv_phone_path)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_idv_continue
      expect(page).to have_current_path(idv_otp_delivery_method_path)
    end
  end

  it_behaves_like 'async timed out'

  context "when the user's information cannot be verified" do
    it_behaves_like 'fail to verify idv info', :phone

    it 'links to verify by mail, from which user can return back to the warning screen' do
      start_idv_from_sp
      complete_idv_steps_before_phone_step
      fill_out_phone_form_fail
      click_idv_continue

      expect(page).to have_content(t('idv.failure.phone.warning'))

      click_on t('idv.troubleshooting.options.verify_by_mail')
      expect(page).to have_content(t('idv.titles.mail.verify'))

      click_doc_auth_back_link
      expect(page).to have_content(t('idv.failure.phone.warning'))
    end

    it 'does not render the link to proof by mail if proofing by mail is disabled' do
      allow(FeatureManagement).to receive(:enable_gpo_verification?).and_return(false)

      start_idv_from_sp
      complete_idv_steps_before_phone_step

      4.times do
        fill_out_phone_form_fail
        click_idv_continue

        expect(page).to have_content(t('idv.failure.phone.warning'))
        expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

        click_on t('idv.failure.button.warning')
      end

      fill_out_phone_form_fail
      click_idv_continue

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
end
