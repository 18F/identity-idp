require 'rails_helper'

RSpec.describe 'webauthn hide' do
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

    before do
      allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).and_return(true)
    end

    context 'on sign up' do
      context 'with javascript enabled', :js do
        it 'does not display the authenticator option' do
          sign_up_and_set_password

          expect(webauthn_option_hidden?).to eq(true)
        end

        context 'with supported browser', driver: :headless_chrome_mobile do
          it 'displays the authenticator option' do
            sign_up_and_set_password

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
        it 'displays the authenticator option' do
          sign_in_user(user)
          click_on t('two_factor_authentication.login_options_link_text')

          expect(webauthn_option_hidden?).to eq(false)
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
    page.find("label[for=#{option_id}]")
    false
  rescue Capybara::ElementNotFound
    true
  end
end
