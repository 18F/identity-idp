require 'rails_helper'

RSpec.describe 'shared/_cancel_or_back_to_options.html.erb' do
  let(:user) { build(:user) }
  let(:in_multi_mfa_selection_flow) { false }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:in_multi_mfa_selection_flow?).and_return(in_multi_mfa_selection_flow)
  end

  it 'renders link to choose another authentication method' do
    expect(rendered).to have_link(
      t('two_factor_authentication.choose_another_option'),
      href: authentication_methods_setup_path,
    )
  end

  context 'with mfa configured' do
    let(:user) { build(:user, :with_phone) }

    it 'renders link to cancel and return to account' do
      expect(rendered).to have_link(t('links.cancel'), href: account_path)
    end

    context 'when in multi mfa selection flow' do
      let(:in_multi_mfa_selection_flow) { true }

      it 'renders link to choose another authentication method' do
        expect(rendered).to have_link(
          t('two_factor_authentication.choose_another_option'),
          href: authentication_methods_setup_path,
        )
      end
    end
  end
end
