require 'rails_helper'

describe 'users/piv_cac_authentication_setup/new.html.slim' do
  context 'user has sufficient factors' do
    it 'renders a link to cancel and go back to the account page' do
      user = create(:user, :signed_up)
      allow(view).to receive(:current_user).and_return(user)
      form = OpenStruct.new
      @presenter = PivCacAuthenticationSetupPresenter.new(user, form)

      render

      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end
  end

  context 'user is setting up 2FA' do
    it 'renders a link to choose a different option' do
      user = create(:user)
      allow(view).to receive(:current_user).and_return(user)
      form = OpenStruct.new
      @presenter = PivCacAuthenticationSetupPresenter.new(user, form)

      render

      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: two_factor_options_path,
      )
    end
  end
end
