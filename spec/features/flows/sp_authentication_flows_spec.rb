require 'rails_helper'

include SamlAuthHelper

feature 'SP-initiated authentication with login.gov', devise: true, user_flow: true do
  context 'with a valid SP' do
    before do
      visit authnrequest_get
    end

    it 'prompts the user to create an account or sign in' do
      screenshot_and_save_page
    end

    context 'when choosing Create Account' do
      before do
        click_link t('sign_up.registrations.create_account')
      end

      it 'displays an interstitial page with information' do
        screenshot_and_save_page
      end

      it 'prompts for email address' do
        screenshot_and_save_page
      end

      context 'with a valid email address submitted' do
        before do
          @email = Faker::Internet.safe_email
          fill_in 'Email', with: @email
          click_button t('forms.buttons.submit.default')
          @user = User.find_with_email(@email)
        end

        it 'informs the user to check email' do
          screenshot_and_save_page
        end

        context 'with a confirmed email address' do
          before do
            confirm_last_user
          end

          it 'prompts the user for a password' do
            screenshot_and_save_page
          end

          context 'with a valid password' do
            before do
              fill_in 'password_form_password', with: Features::SessionHelper::VALID_PASSWORD
              click_button t('forms.buttons.continue')
            end

            it 'prompts the user to configure 2FA' do
              screenshot_and_save_page
            end

            context 'with a valid phone number' do
              before do
                fill_in 'Phone', with: Faker::PhoneNumber.cell_phone
              end

              context 'with SMS delivery' do
                before do
                  choose t('devise.two_factor_authentication.otp_delivery_preference.sms')
                  click_send_security_code
                end

                it 'prompts for OTP' do
                  screenshot_and_save_page
                end
              end

              context 'with Voice delivery' do
                before do
                  choose t('devise.two_factor_authentication.otp_delivery_preference.voice')
                  click_send_security_code
                end

                it 'prompts for OTP' do
                  screenshot_and_save_page
                end
              end
            end
          end
        end
      end
    end

    context 'when choosing to sign in' do
      before do
        @user = create(:user, :signed_up)
        click_link t('links.sign_in')
      end

      context 'with valid credentials entered' do
        before do
          fill_in_credentials_and_submit(@user.email, @user.password)
        end

        it 'prompts for 2FA delivery method' do
          screenshot_and_save_page
        end

        context 'with SMS OTP selected (default)' do
          it 'prompts for OTP verification' do
            screenshot_and_save_page
          end

          context 'with valid OTP confirmation' do
            before do
              fill_in 'code', with: @user.reload.direct_otp
              click_button t('forms.buttons.submit.default')
            end

            xit 'redirects back to SP' do
              screenshot_and_save_page
            end
          end
        end
      end

      context 'without a valid username and password' do
        context 'when choosing "Forgot your password?"' do
          before do
            click_link t('links.passwords.forgot')
          end

          it 'prompts for my email address' do
            screenshot_and_save_page
          end

          context 'with not_a_real_email_dot.com submitted' do
            before do
              fill_in 'password_reset_email_form_email', with: 'not_a_real_email_dot.com'
              click_button t('forms.buttons.continue')
            end

            it 'displays a useful error' do
              screenshot_and_save_page
            end
          end
        end
      end
    end
  end
end
