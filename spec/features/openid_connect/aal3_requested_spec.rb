require 'rails_helper'

describe 'OpenID Connect requesting AAL3 authentication' do
  include IdvHelper
  include OidcAuthHelper
  include DocAuthHelper

  context 'visiting IdP via AAL3 SP' do
    it 'sends user to set up AAL3 auth' do
      user = user_with_2fa

      visit_idp_from_ial1_aal3_oidc_sp(prompt: 'select_account')
      sign_in_live_with_2fa(user)

      expect(current_url).to eq(two_factor_options_url)
      expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(page).to have_xpath("//img[@alt='important alert icon']")
    end
  end
end
