require 'rails_helper'

RSpec.describe 'users/piv_cac_authentication_setup/new.html.erb' do
  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:in_multi_mfa_selection_flow) { false }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:user_session).and_return(user_session)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(in_multi_mfa_selection_flow)
    form = UserPivCacSetupForm.new
    @presenter = PivCacAuthenticationSetupPresenter.new(user, true, form)
  end

  it 'does not show option to skip setting up piv/cac' do
    expect(rendered).not_to have_button(t('mfa.skip'))
  end

  context 'user has sufficient factors' do
    let(:user) { create(:user, :fully_registered) }

    it 'renders a link to cancel and go back to the account page' do
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    context 'user is in the process of setting up multiple MFAs' do
      let(:in_multi_mfa_selection_flow) { true }

      it 'renders a link to choose a different option' do
        expect(rendered).to have_link(
          t('two_factor_authentication.choose_another_option'),
          href: authentication_methods_setup_path,
        )
      end
    end
  end

  context 'user is setting up 2FA' do
    let(:user) { create(:user) }

    it 'renders a link to choose a different option' do
      expect(rendered).to have_link(
        t('two_factor_authentication.choose_another_option'),
        href: authentication_methods_setup_path,
      )
    end
  end

  context 'when adding piv cac after 2fa' do
    let(:user_session) { { add_piv_cac_after_2fa: true } }

    it 'shows option to skip setting up piv/cac' do
      expect(rendered).to have_button(t('mfa.skip'))
    end

    it 'renders a link to cancel and sign out' do
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
    end

    context 'when SP requires PIV/CAC' do
      before do
        @piv_cac_required = true
      end

      it 'does not show option to skip setting up piv/cac' do
        expect(rendered).not_to have_button(t('mfa.skip'))
      end

      it 'renders a link to cancel and sign out' do
        expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
      end
    end
  end
end
