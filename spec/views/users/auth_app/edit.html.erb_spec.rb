require 'rails_helper'

RSpec.describe 'users/auth_app/edit.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nickname) { 'Example' }
  let(:configuration) { create(:auth_app_configuration, name: nickname) }
  let(:user) { create(:user, auth_app_configurations: [configuration]) }
  let(:form) do
    TwoFactorAuthentication::AuthAppUpdateForm.new(
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
      "form[action='#{auth_app_path(id: configuration.id)}'] input[name='_method'][value='put']",
      visible: false,
    )
  end

  it 'initializes form with configuration values' do
    expect(rendered).to have_field(
      t('two_factor_authentication.auth_app.nickname'),
      with: nickname,
    )
  end

  it 'has a link to confirm deleting the configuration' do
    expect(rendered).to have_link(
      t('two_factor_authentication.auth_app.delete'),
      href: confirm_delete_auth_app_path(id: configuration.id),
    )
  end
end
