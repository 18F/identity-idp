require 'rails_helper'

feature 'IdV session', idv_job: true do
  include IdvHelper

  context 'landing page' do
    before do
      sign_in_and_2fa_user
      visit verify_path
    end

    scenario 'decline to verify identity' do
      click_link t('links.cancel')
      expect(page).to have_content(t('idv.titles.cancel'))
    end

    scenario 'proceed to verify identity' do
      click_link 'Yes'

      expect(page).to have_content(t('idv.titles.sessions'))
    end
  end

  context 'verification session' do
    scenario 'normal flow' do
      user = sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue

      expect(page).to have_content(
        t('idv.messages.sessions.success',
          pii_message: t('idv.messages.sessions.pii'))
      )

      click_idv_address_choose_phone
      fill_out_phone_form_ok(user.phone)
      click_idv_continue
      fill_in :user_password, with: user_password
      click_submit_default

      expect(current_url).to eq verify_confirmations_url
      expect(page).to have_content(t('headings.personal_key'))
      click_acknowledge_personal_key

      expect(current_url).to eq(account_url)
      expect(page).to have_content('José One')
      expect(page).to have_content('123 Main St')
      expect(user.reload.active_profile).to be_a(Profile)
    end

    scenario 'vendor agent throws exception' do
      first_name_to_trigger_exception = 'Fail'

      sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      fill_in 'profile_first_name', with: first_name_to_trigger_exception

      expect(Idv::ProfileJob).to receive(:perform_now).and_wrap_original do |perform, *args|
        exception_raised = false
        begin
          perform.call(*args)
        rescue RuntimeError => err
          expect(err.message).to eq('Failed to contact proofing vendor')
          exception_raised = true
        ensure
          expect(exception_raised).to eq(true)
        end
      end

      click_idv_continue

      expect(current_path).to eq(verify_session_result_path)
      expect(page).to have_css('.modal-warning', text: t('idv.modal.sessions.heading'))
    end

    scenario 'profile steps is not re-entrant and are sticky on failure', :js do
      user = sign_in_and_2fa_user

      visit verify_session_path

      first_ssn_value = '666-66-6666'
      second_ssn_value = '666-66-1234'
      good_phone_value = '415-555-9999'
      good_phone_formatted = '+1 (415) 555-9999'
      bad_phone_formatted = '+1 (555) 555-5555'

      # we start with blank form
      expect(page).to_not have_selector("input[value='#{first_ssn_value}']")

      fill_out_idv_form_fail
      click_idv_continue

      # failure reloads the form and shows warning modal
      expect(current_path).to eq verify_session_result_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.sessions.heading'))
      click_button t('idv.modal.button.warning')

      fill_out_idv_form_ok
      click_idv_continue

      # address mechanism choice
      click_idv_address_choose_phone

      # success advances to next step
      expect(current_path).to eq verify_phone_path

      # we start with blank form
      expect(page).to_not have_selector("input[value='#{bad_phone_formatted}']")

      fill_out_phone_form_fail
      click_idv_continue

      # failure reloads the same sticky form
      expect(current_path).to eq verify_phone_result_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.phone.heading'))
      click_button t('idv.modal.button.warning')
      expect(page).to have_selector("input[value='#{bad_phone_formatted}']")

      fill_out_phone_form_ok(good_phone_value)
      click_idv_continue
      choose_idv_otp_delivery_method_sms
      enter_correct_otp_code_for_user(user)

      page.find('.accordion').click

      # success advances to next step
      expect(page).to have_content(t('idv.titles.session.review'))
      expect(page).to have_content(second_ssn_value)
      expect(page).to_not have_content(first_ssn_value)
      expect(page).to have_content(good_phone_formatted)
      expect(page).to_not have_content(bad_phone_formatted)
    end

    scenario 'phone step is re-entrant', :js do
      phone = '+1 (555) 555-5000'
      different_phone = '+1 (777) 777-7000'
      user = sign_in_and_2fa_user

      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok(phone)
      click_idv_continue
      choose_idv_otp_delivery_method_sms

      click_link t('forms.two_factor.try_again')

      expect(page.find('#idv_phone_form_phone').value).to eq(phone)
      expect(current_path).to eq(verify_phone_path)

      fill_out_phone_form_ok(different_phone)
      click_idv_continue
      choose_idv_otp_delivery_method_sms

      # Verify that OTP confirmation can't be skipped
      visit verify_review_path
      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :sms)

      enter_correct_otp_code_for_user(user)

      page.find('.accordion').click

      expect(page).to_not have_content(phone)
      expect(page).to have_content(different_phone)
    end

    scenario 'failed attempt shows flash message' do
      sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_fail
      click_idv_continue

      expect(page).to have_content t('idv.modal.sessions.warning')
    end

    scenario 'closing previous address accordion clears inputs and toggles header', js: true do
      _user = sign_in_and_2fa_user

      visit verify_session_path
      expect(page).to have_css('.accordion-header-controls',
                               text: t('idv.form.previous_address_add'))

      click_accordion
      expect(page).to have_css('.accordion-header', text: t('links.remove'))

      fill_out_idv_previous_address_ok
      expect(find('#profile_prev_address1').value).to eq '456 Other Ave'

      click_accordion
      click_accordion

      expect(find('#profile_prev_address1').value).to eq ''
    end

    context 'personal keys information and actions' do
      before do
        personal_key = 'a1b2c3d4e5f6g7h8'

        @user = sign_in_and_2fa_user
        visit verify_session_path

        allow(RandomPhrase).to receive(:to_s).and_return(personal_key)
        complete_idv_profile_ok(@user)
      end

      scenario 'personal key presented on success' do
        expect(page).to have_content(t('headings.personal_key'))
      end

      it_behaves_like 'personal key page'

      scenario 'reload personal key page' do
        visit current_path

        expect(page).to have_content(t('headings.personal_key'))

        visit current_path

        expect(page).to have_content(t('headings.personal_key'))
      end
    end

    context 'cancel from USPS/Phone verification screen' do
      context 'without js' do
        it 'returns user to profile path' do
          sign_in_and_2fa_user
          loa3_sp_session
          visit verify_session_path

          fill_out_idv_form_ok
          click_idv_continue

          click_idv_cancel

          expect(current_path).to eq(account_path)
        end
      end

      context 'with js', js: true do
        it 'redirects to profile from a modal' do
          sign_in_and_2fa_user
          loa3_sp_session
          visit verify_session_path

          fill_out_idv_form_ok
          click_idv_continue

          click_on t('links.cancel_idv')
          click_idv_cancel_modal

          expect(current_path).to eq(account_path)
        end
      end
    end

    scenario 'cancelling phone OTP verification redirects to verification cancel' do
      allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('4')
      different_phone = '555-555-9876'

      sign_in_and_2fa_user
      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok(different_phone)
      click_idv_continue
      choose_idv_otp_delivery_method_sms

      click_on t('links.cancel')

      expect(current_path).to eq verify_cancel_path
    end

    scenario 'attempting to skip OTP phone confirmation redirects to OTP confirmation', :js do
      different_phone = '555-555-9876'
      user = sign_in_live_with_2fa
      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok(different_phone)
      click_idv_continue

      # Modify URL to skip phone confirmation
      visit verify_review_path
      user.reload

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
      expect(user.profiles).to be_empty
    end
  end

  def click_accordion
    find('.accordion-header-controls').click
  end
end
