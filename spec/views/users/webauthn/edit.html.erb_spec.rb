require 'rails_helper'

RSpec.describe 'users/webauthn/edit.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nickname) { 'Example' }
  let(:configuration) { create(:webauthn_configuration, :platform_authenticator, name: nickname) }
  let(:user) { create(:user, webauthn_configurations: [configuration]) }
  let(:form) do
    TwoFactorAuthentication::WebauthnUpdateForm.new(
      user:,
      configuration_id: configuration.id,
    )
  end

  subject(:rendered) { render }

  before do
    @form = form
  end

  it 'renders form to update configuration' do
    expect(rendered).to have_selector(
      "form[action='#{webauthn_path(id: configuration.id)}'] input[name='_method'][value='put']",
      visible: false,
    )
  end

  it 'initializes form with configuration values' do
    expect(rendered).to have_field(
      t('two_factor_authentication.webauthn_platform.nickname'),
      with: nickname,
    )
  end

  it 'has labelled form with button to delete configuration' do
    expect(rendered).to have_button_to_with_accessibility(
      t('two_factor_authentication.webauthn_platform.delete'),
      webauthn_path(id: configuration.id),
    )
  end
end
