require 'rails_helper'

RSpec.describe 'two_factor_authentication/totp_verification/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_authentication_app) }
  let(:presenter_data) do
    attributes_for(:generic_otp_presenter).merge(
      two_factor_authentication_method: 'authenticator',
    )
  end

  before do
    allow(view).to receive(:current_user).and_return(user)
    @presenter = TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(
      data: presenter_data, view: ActionController::Base.new.view_context, service_provider: nil,
    )
    allow(@presenter).to receive(:reauthn).and_return(false)

    render
  end

  it_behaves_like 'an otp form'

  it 'uses numeric input mode (to allow leading zeroes)' do
    render

    code_input = Nokogiri::HTML(rendered).at_css('input#code')
    expect(code_input[:inputmode]).to eq('numeric')
  end

  it 'shows the correct header' do
    expect(rendered).to have_content t('two_factor_authentication.totp_header_text')
  end

  it 'shows the correct help text' do
    expect(rendered).to have_content 'Enter the code from your authenticator app.'
    expect(rendered).to have_content "enter the code corresponding to #{APP_NAME}"
  end

  it 'allows the user to fallback to SMS and voice' do
    expect(rendered).to have_link(
      t('two_factor_authentication.login_options_link_text'),
      href: login_two_factor_options_path,
    )
  end

  it 'provides an option to use a personal key' do
    expect(rendered).to have_link(
      t('two_factor_authentication.login_options_link_text'),
      href: login_two_factor_options_path,
    )
  end

  context 'user is reauthenticating' do
    before do
      allow(@presenter).to receive(:reauthn).and_return(true)
      render
    end

    it 'provides a cancel link to return to profile' do
      expect(rendered).to have_link(
        t('links.cancel'),
        href: account_path,
      )
    end

    it 'renders the reauthn partial' do
      expect(view).to render_template(
        partial: 'two_factor_authentication/totp_verification/_reauthn',
      )
    end
  end
end
