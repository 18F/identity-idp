require 'rails_helper'

describe 'two_factor_authentication/options/index.html.erb' do
  let(:user) { User.new }
  before do
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:current_user).and_return(User.new)

    @presenter = TwoFactorLoginOptionsPresenter.new(
      user: user,
      view: view,
      user_session_context: UserSessionContext::DEFAULT_CONTEXT,
      service_provider: nil,
      aal3_required: false,
      piv_cac_required: false,
    )
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with( \
      t('two_factor_authentication.login_options_title'),
    )

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content \
      t('two_factor_authentication.login_options_title')
  end

  it 'has a cancel link' do
    render

    expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
  end
end
