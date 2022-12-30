require 'rails_helper'

describe 'webauthn hide' do
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
    let(:user) { create(:user, :signed_up, :with_webauthn) }

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

  def webauthn_option_hidden?
    page.find('label[for=two_factor_options_form_selection_webauthn]').ancestor('.display-none')
    true
  rescue Capybara::ElementNotFound
    false
  end
end
