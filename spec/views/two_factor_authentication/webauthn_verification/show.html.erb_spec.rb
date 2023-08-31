require 'rails_helper'

RSpec.describe 'two_factor_authentication/webauthn_verification/show.html.erb' do
  let(:user) { build_stubbed(:user) }
  let(:platform_authenticator) { false }
  subject(:rendered) { render }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:sp_session).and_return({})
    @presenter = TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
      view:,
      data: {},
      service_provider: nil,
      platform_authenticator:,
    )
  end

  it 'includes hidden platform form input with value false' do
    expect(rendered).to have_field('platform', with: 'false', type: 'hidden')
  end

  context 'with platform authenticator' do
    let(:platform_authenticator) { true }

    it 'includes hidden platform form input with value false' do
      expect(rendered).to have_field('platform', with: 'true', type: 'hidden')
    end
  end
end
