require 'rails_helper'

RSpec.describe 'webauthn hide' do
  include JavascriptDriverHelper
  include WebAuthnHelper
  include AbTestsHelper

  describe 'security key' do
    let(:option_id) { 'two_factor_options_form_selection_webauthn' }

    context 'on sign up' do
      context 'with javascript enabled', :js do
        it 'displays the security key option' do
          sign_up_and_set_password

          expect(webauthn_option_hidden?).to eq(false)
        end
      end

      context 'with javascript disabled' do
        it 'does not display the security key option' do
          sign_up_and_set_password

          expect(webauthn_option_hidden?).to eq(true)
        end
      end
    end

    context 'on sign in' do
      let(:user) { create(:user, :fully_registered, :with_webauthn) }

      context 'with javascript enabled', :js do
        it 'displays the security key option' do
          sign_in_user(user)
          click_on t('two_factor_authentication.login_options_link_text')

          expect(webauthn_option_hidden?).to eq(false)
        end
      end

      context 'with javascript disabled' do
        it 'does not display the security key option' do
          sign_in_user(user)
          click_on t('two_factor_authentication.login_options_link_text')

          expect(webauthn_option_hidden?).to eq(true)
        end
      end
    end
  end

  describe 'platform authenticator' do
    let(:option_id) { 'two_factor_options_form_selection_webauthn_platform' }

    context 'on sign up' do
      context 'with javascript enabled', :js do
        it 'does not display the authenticator option' do
          sign_up_and_set_password

          expect(webauthn_option_hidden?).to eq(true)
        end

        context 'with supported browser and platform authenticator available',
                driver: :headless_chrome_mobile do
          it 'displays the authenticator option' do
            sign_up_and_set_password
            simulate_platform_authenticator_available

            expect(webauthn_option_hidden?).to eq(false)
          end
        end
      end

      context 'with javascript disabled' do
        it 'does not display the authenticator option' do
          sign_up_and_set_password

          expect(webauthn_option_hidden?).to eq(true)
        end
      end
    end

    context 'on sign in' do
      let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

      context 'with javascript enabled', :js do
        context ' with device that supports authenticator' do
          it 'displays the authenticator option' do
            sign_in_user(user)
            click_on t('two_factor_authentication.login_options_link_text')

            expect(webauthn_option_hidden?).to eq(false)
          end
        end

        context 'with device that doesnt support authenticator' do
          it 'redirects to options page and allows them to choose authenticator' do
            visit new_user_session_path
            set_hidden_field('platform_authenticator_available', 'false')
            fill_in_credentials_and_submit(user.email, user.password)

            # Redirected to options page
            expect(page).to have_current_path(login_two_factor_options_path)

            # Can choose authenticator
            expect(webauthn_option_hidden?).to eq(false)
            choose t('two_factor_authentication.login_options.webauthn_platform')
            click_continue
            expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
          end

          context 'if the webauthn credential is not their default mfa method when signing in' do
            let(:user) do
              create(:user, :fully_registered, :with_piv_or_cac, :with_webauthn_platform)
            end

            it 'allows them to choose authenticator if they change from their default method' do
              visit new_user_session_path
              set_hidden_field('platform_authenticator_available', 'false')
              fill_in_credentials_and_submit(user.email, user.password)

              # Redirected to default MFA method
              expect(page).to have_current_path(login_two_factor_piv_cac_path)

              # Can change to authenticator if they choose
              click_on t('two_factor_authentication.login_options_link_text')
              choose t('two_factor_authentication.login_options.webauthn_platform')
              click_continue
              expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
            end
          end
        end
      end

      context 'with javascript disabled' do
        it 'does not display the authenticator option' do
          sign_in_user(user)
          click_on t('two_factor_authentication.login_options_link_text')

          expect(webauthn_option_hidden?).to eq(true)
        end
      end
    end
  end

  def webauthn_option_hidden?
    label = page.find("label[for=#{option_id}]", visible: :all)
    if javascript_enabled?
      !label.visible?
    else
      label.ancestor('.js,[hidden]', visible: :all).present?
    end
  end
end
