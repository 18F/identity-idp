require 'rails_helper'

describe 'users/piv_cac_authentication_setup/new.html.erb' do
  context 'user has sufficient factors' do
    it 'renders a link to cancel and go back to the account page' do
      user = create(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(signing_up: false)
      allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(false)
      form = OpenStruct.new
      @presenter = PivCacAuthenticationSetupPresenter.new(user, true, form)

      render

      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end
  end

  context 'user is setting up 2FA' do
    it 'renders a link to choose a different option' do
      user = create(:user)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:user_session).and_return(signing_up: true)
      form = OpenStruct.new
      @presenter = PivCacAuthenticationSetupPresenter.new(user, false, form)

      render

      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: authentication_methods_setup_path,
      )
    end
  end
end
