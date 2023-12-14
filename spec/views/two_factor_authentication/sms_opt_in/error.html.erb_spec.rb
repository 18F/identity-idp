require 'rails_helper'

RSpec.describe 'two_factor_authentication/sms_opt_in/error.html.erb' do
  let(:phone_configuration) { build(:phone_configuration, phone: '1 888-867-5309') }
  let(:presenter) { TwoFactorAuthCode::SmsOptInPresenter.new }
  let(:cancel_url) { '/account' }

  before do
    assign(:phone_configuration, phone_configuration)
    assign(:presenter, presenter)
    assign(:cancel_url, cancel_url)
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  it 'renders the masked phone number' do
    render

    expect(rendered).to have_content('(***) ***-5309')
  end

  it 'renders troubleshooting options' do
    render

    expect(rendered).to have_link(
      t('two_factor_authentication.login_options_link_text'),
      href: login_two_factor_options_path,
    )
    expect(rendered).to have_link(
      t('two_factor_authentication.learn_more'),
      href: help_center_redirect_path(
        category: 'get-started',
        article: 'authentication-options',
        flow: :two_factor_authentication,
        step: :sms_opt_in,
      ),
    )
  end
end
