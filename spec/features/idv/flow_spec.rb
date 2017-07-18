require 'rails_helper'

feature 'IdV session' do
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

      expect(page).to have_content(t('idv.form.ccn'))
      expect(page).to have_content(
        t('idv.messages.sessions.success',
          pii_message: t('idv.messages.sessions.pii'))
      )

      fill_out_financial_form_ok
      click_idv_continue
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
      click_idv_continue

      expect(current_path).to eq verify_session_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.sessions.heading'))
    end

    scenario 'allows 3 attempts in 24 hours' do
      user = sign_in_and_2fa_user

      max_attempts_less_one.times do
        visit verify_session_path
        complete_idv_profile_fail

        expect(current_path).to eq verify_session_path
      end

      user.reload
      expect(user.idv_attempted_at).to_not be_nil

      visit destroy_user_session_url
      sign_in_and_2fa_user(user)

      visit verify_session_path
      complete_idv_profile_fail

      expect(page).to have_css('.alert-error', text: t('idv.modal.sessions.heading'))

      visit verify_session_path

      expect(page).to have_content(t('idv.errors.hardfail'))
      expect(current_url).to eq verify_fail_url

      user.reload
      expect(user.idv_attempted_at).to_not be_nil
    end

    scenario 'finance shows failure flash message after max attempts' do
      sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue

      max_attempts_less_one.times do
        fill_out_financial_form_fail
        click_idv_continue

        expect(current_path).to eq verify_finance_path
      end

      fill_out_financial_form_fail
      click_idv_continue
      expect(page).to have_css('.alert-error', text: t('idv.modal.financials.heading'))
    end

    scenario 'finance shows failure modal after max attempts', js: true do
      sign_in_and_2fa_user
      visit verify_session_path
      max_attempts_less_one.times do
        fill_out_idv_form_fail
        click_idv_continue
        click_button t('idv.modal.button.warning')
      end

      fill_out_idv_form_fail
      click_idv_continue
      expect(page).to have_css('.modal-fail', text: t('idv.modal.sessions.heading'))
    end

    scenario 'successful steps are not re-entrant, but are sticky on failure', js: true do
      _user = sign_in_and_2fa_user

      visit verify_session_path

      first_ssn_value = '666-66-6666'
      second_ssn_value = '666-66-1234'
      first_ccn_value = '00000000'
      second_ccn_value = '12345678'
      mortgage_value = '00000000'
      good_phone_value = '415-555-9999'
      good_phone_formatted = '+1 (415) 555-9999'
      bad_phone_formatted = '+1 (555) 555-5555'

      # we start with blank form
      expect(page).to_not have_selector("input[value='#{first_ssn_value}']")

      fill_out_idv_form_fail
      click_idv_continue

      # failure reloads the form and shows warning modal
      expect(current_path).to eq verify_session_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.sessions.heading'))
      click_button t('idv.modal.button.warning')

      fill_out_idv_form_ok
      click_idv_continue

      # success advances to next step
      expect(current_path).to eq verify_finance_path

      # we start with blank form
      expect(page).to_not have_selector("input[value='#{first_ccn_value}']")

      fill_in :idv_finance_form_ccn, with: first_ccn_value
      click_idv_continue

      # failure reloads the form and shows warning modal
      expect(current_path).to eq verify_finance_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.financials.heading'))
      click_button t('idv.modal.button.warning')

      # can't go "back" to a successful step
      visit verify_session_path
      expect(current_path).to eq verify_finance_path

      # re-entering a failed step is sticky
      expect(page).to have_content(t('idv.form.ccn'))
      expect(page).to have_selector("input[value='#{first_ccn_value}']")

      # try again, but with different finance type
      click_link t('idv.form.use_financial_account')

      expect(current_path).to eq verify_finance_other_path

      select t('idv.form.mortgage'), from: 'idv_finance_form_finance_type'
      fill_in :idv_finance_form_mortgage, with: mortgage_value
      click_idv_continue

      # failure reloads the same sticky form (different path) and shows warning modal
      expect(current_path).to eq verify_finance_path
      click_button t('idv.modal.button.warning')
      expect(page).to have_selector("input[value='#{mortgage_value}']")

      # try again with CCN
      click_link t('idv.form.use_ccn')
      fill_in :idv_finance_form_ccn, with: second_ccn_value
      click_idv_continue

      # address mechanism choice
      expect(current_path).to eq verify_address_path
      click_idv_address_choose_phone

      # success advances to next step
      expect(current_path).to eq verify_phone_path

      # we start with blank form
      expect(page).to_not have_selector("input[value='#{bad_phone_formatted}']")

      fill_out_phone_form_fail
      click_idv_continue

      # failure reloads the same sticky form
      expect(current_path).to eq verify_phone_path
      expect(page).to have_css('.modal-warning', text: t('idv.modal.phone.heading'))
      click_button t('idv.modal.button.warning')
      expect(page).to have_selector("input[value='#{bad_phone_formatted}']")

      fill_out_phone_form_ok(good_phone_value)
      click_idv_continue

      page.find('.accordion').click

      # success advances to next step
      expect(page).to have_content(t('idv.titles.session.review'))
      expect(page).to have_content(second_ssn_value)
      expect(page).to_not have_content(first_ssn_value)
      expect(page).to_not have_content(second_ccn_value)
      expect(page).to_not have_content(mortgage_value)
      expect(page).to_not have_content(first_ccn_value)
      expect(page).to have_content(good_phone_formatted)
      expect(page).to_not have_content(bad_phone_formatted)
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

    scenario 'clicking finance option changes input label', js: true do
      _user = sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue

      expect(page).to_not have_css('.js-finance-wrapper', text: t('idv.form.mortgage'))

      click_link t('idv.form.use_financial_account')

      expect(page).to_not have_content(t('idv.form.ccn'))
      expect(page).to have_css('input[type=submit][disabled]')
      expect(page).to have_css('.js-finance-wrapper', text: t('idv.form.auto_loan'), visible: false)

      select t('idv.form.auto_loan'), from: 'idv_finance_form_finance_type'

      expect(page).to have_css('.js-finance-wrapper', text: t('idv.form.auto_loan'), visible: true)
    end

    scenario 'enters invalid finance value', js: true do
      _user = sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue
      click_link t('idv.form.use_financial_account')

      select t('idv.form.mortgage'), from: 'idv_finance_form_finance_type'
      short_value = '1' * (FormFinanceValidator::VALID_MINIMUM_LENGTH - 1)
      fill_in :idv_finance_form_mortgage, with: short_value
      click_button t('forms.buttons.continue')

      expect(page).to have_content(
        t(
          'idv.errors.finance_number_length',
          minimum: FormFinanceValidator::VALID_MINIMUM_LENGTH,
          maximum: FormFinanceValidator::VALID_MAXIMUM_LENGTH
        )
      )
    end

    scenario 'credit card field only allows numbers', js: true do
      _user = sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue

      find('#idv_finance_form_ccn').native.send_keys('abcd1234')

      expect(find('#idv_finance_form_ccn').value).to eq '1234'
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
          fill_out_financial_form_ok
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
          fill_out_financial_form_ok
          click_idv_continue

          click_on t('links.cancel_idv')
          click_idv_cancel_modal

          expect(current_path).to eq(account_path)
        end
      end
    end

    scenario 'continue phone OTP verification after cancel' do
      allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('4')

      different_phone = '555-555-9876'
      user = sign_in_live_with_2fa
      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue
      fill_out_financial_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok(different_phone)
      click_idv_continue
      fill_in :user_password, with: user_password
      click_submit_default

      click_on t('links.cancel')

      expect(current_path).to eq root_path

      sign_in_live_with_2fa(user)

      expect(page).to have_content('9876')
      expect(page).to have_content(t('account.index.verification.instructions'))

      enter_correct_otp_code_for_user(user)

      expect(current_path).to eq account_path
    end

    scenario 'being unable to verify account without OTP phone confirmation' do
      different_phone = '555-555-9876'
      user = sign_in_live_with_2fa
      visit verify_session_path

      fill_out_idv_form_ok
      click_idv_continue
      fill_out_financial_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok(different_phone)
      click_idv_continue
      fill_in :user_password, with: user_password
      click_submit_default

      visit verify_confirmations_path
      click_acknowledge_personal_key

      user.reload

      expect(user.active_profile).to be_nil
    end
  end

  def complete_idv_profile_fail
    fill_out_idv_form_fail
    click_button 'Continue'
  end

  def click_accordion
    find('.accordion-header-controls').click
  end
end
