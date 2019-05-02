require 'rails_helper'

feature 'SP-initiated authentication with login.gov', :user_flow do
  include IdvHelper
  include SamlAuthHelper

  I18n.available_locales.each do |locale|
    context "with locale=#{locale}" do
      context 'with a valid SP' do
        context 'when LOA3' do
          before do
            visit "#{loa3_authnrequest}&locale=#{locale}"
          end

          it 'prompts the user to create an account or sign in' do
            screenshot_and_save_page
          end

          context 'when choosing Create Account' do
            before do
              click_link t('links.create_account')
            end

            it 'prompts for email address' do
              screenshot_and_save_page
            end

            context 'with a valid email address submitted' do
              before do
                @email = Faker::Internet.safe_email
                fill_in 'user_email', with: @email
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
                      complete_phone_form_with_valid_phone
                    end

                    context 'with SMS delivery' do
                      before do
                        choose t('two_factor_authentication.otp_delivery_preference.sms')
                        click_send_security_code
                      end

                      it 'prompts for OTP' do
                        screenshot_and_save_page
                      end

                      context 'with valid OTP confirmation' do
                        before do
                          fill_in 'code', with: @user.reload.direct_otp
                          click_button t('forms.buttons.submit.default')
                        end

                        it 'prompts the user to verify oneself' do
                          screenshot_and_save_page
                        end

                        context 'when choosing Yes, continue' do
                          before do
                            select 'Virginia', from: 'jurisdiction_state'
                            click_idv_continue
                          end

                          it 'prompts for personal information' do
                            screenshot_and_save_page
                          end

                          context 'with valid personal information entered' do
                            before do
                              fill_in 'profile_first_name', with: Faker::Name.first_name
                              fill_in 'profile_last_name', with: Faker::Name.last_name
                              fill_in 'profile_address1', with: '123 Main St'
                              fill_in 'profile_city', with: Faker::Address.city
                              find('#profile_state').
                                find(:xpath, "option[#{(1..50).to_a.sample}]").
                                select_option
                              fill_in 'profile_zipcode', with: Faker::Address.zip_code
                              fill_in 'profile_dob', with: "09/09/#{(1900..2000).to_a.sample}"
                              fill_in 'profile_ssn', with: "999-99-#{(1000..9999).to_a.sample}"
                              click_button t('forms.buttons.continue')
                            end

                            it 'prompts the user to confirm or enter phone number' do
                              screenshot_and_save_page
                            end

                            context 'when activating by mail' do
                              before do
                                click_on t('idv.form.no_alternate_phone_html')
                              end

                              it 'prompts the user to confirm' do
                                screenshot_and_save_page
                              end

                              context 'when confirming to mail' do
                                before do
                                  click_on t('idv.buttons.mail.send')
                                end

                                it 'prompts user for password to encrypt profile' do
                                  screenshot_and_save_page
                                end

                                context 'when confirming password' do
                                  before do
                                    fill_in 'user_password',
                                            with: Features::SessionHelper::VALID_PASSWORD
                                    click_button t('forms.buttons.submit.default')
                                  end

                                  it 'provides a new personal key and prompts to verify' do
                                    screenshot_and_save_page
                                  end

                                  context 'when clicking Continue' do
                                    before do
                                      click_acknowledge_personal_key
                                    end

                                    it 'displays the user profile' do
                                      screenshot_and_save_page
                                    end
                                  end
                                end

                                # Disabling this spec because of js: true issue
                                # Will re-enable this once resolved
                                # context 'when choosing to cancel' do
                                #   before do
                                #     click_button t('links.cancel')
                                #   end

                                #   it 'prompts to continue verification or visit profile' do
                                #     screenshot_and_save_page
                                #   end
                                # end
                              end
                            end
                          end

                          context 'with invalid personal information entered' do
                            before do
                              fill_out_idv_form_fail
                              click_button t('forms.buttons.continue')
                            end

                            it 'presents a modal with current retries remaining' do
                              screenshot_and_save_page
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        context 'when LOA1' do
          before do
            visit "#{authnrequest_get}&locale=#{locale}"
          end

          it 'prompts the user to create an account or sign in' do
            screenshot_and_save_page
          end

          context 'when choosing Create Account' do
            before do
              click_link t('links.create_account')
            end

            it 'prompts for email address' do
              screenshot_and_save_page
            end

            context 'with a valid email address submitted' do
              before do
                @email = Faker::Internet.safe_email
                fill_in 'user_email', with: @email
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
                      complete_phone_form_with_valid_phone
                    end

                    context 'with SMS delivery' do
                      before do
                        choose t('two_factor_authentication.otp_delivery_preference.sms')
                        click_send_security_code
                      end

                      it 'prompts for OTP' do
                        screenshot_and_save_page
                      end
                    end

                    context 'with Voice delivery' do
                      before do
                        choose t('two_factor_authentication.otp_delivery_preference.voice')
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

                  # Skipping since we have nothing to show: this occurs on the SP
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
    end
  end

  def complete_phone_form_with_valid_phone
    phone = Faker::PhoneNumber.cell_phone
    phone = Faker::PhoneNumber.cell_phone until Phonelib.valid_for_country?(phone, 'US')
    fill_in 'user_phone_form_phone', with: phone
  end
end
