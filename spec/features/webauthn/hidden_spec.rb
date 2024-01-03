require 'rails_helper'

RSpec.describe 'webauthn hide' do
  include JavascriptDriverHelper
  include WebAuthnHelper

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
          before do
            Warden.on_next_request do |proxy|
              session = proxy.env['rack.session']
              session[:platform_authenticator_available] = true
            end
          end
          it 'displays the authenticator option' do
            sign_in_user(user)
            click_on t('two_factor_authentication.login_options_link_text')

            expect(webauthn_option_hidden?).to eq(false)
          end
        end
        context 'with device that doesnt support authenticator' do
          it 'redirects to options page on sign in' do
            sign_in_user(user)
            expect(current_path).to eq(login_two_factor_options_path)
          end
        end
      end

      context 'with javascript disabled' do
        before do
          Warden.on_next_request do |proxy|
            session = proxy.env['rack.session']
            session[:platform_authenticator_available] = true
          end
        end
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
