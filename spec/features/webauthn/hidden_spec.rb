require 'rails_helper'

describe 'webauthn hide' do
  context 'with javascript enabled', :js do
    it 'displays the security key option' do
      sign_up_and_set_password
      webauthn_option = page.find('label[for=two_factor_options_form_selection_webauthn]')

      expect(webauthn_option).to be_visible
    end
  end

  context 'with javascript disabled' do
    it 'does not display the security key option' do
      sign_up_and_set_password
      webauthn_option = page.find(
        'label[for=two_factor_options_form_selection_webauthn]',
      )

      expect(webauthn_option[:class]).to include('hide')
    end
  end
end
