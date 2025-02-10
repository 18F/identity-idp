require 'rails_helper'

RSpec.describe 'users/piv_cac/edit.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:nickname) { 'Example' }
  let(:configuration) { create(:piv_cac_configuration, name: nickname) }
  let(:user) { create(:user, piv_cac_configurations: [configuration]) }
  let(:form) do
    TwoFactorAuthentication::PivCacUpdateForm.new(
      user:,
      configuration_id: configuration.id,
    )
  end
  let(:presenter) do
    TwoFactorAuthentication::PivCacEditPresenter.new
  end

  subject(:rendered) { render }

  before do
    @form = form
    @presenter = presenter
  end

  it 'renders form to update configuration' do
    expect(rendered).to have_selector(
      "form[action='#{piv_cac_path(id: configuration.id)}'] input[name='_method'][value='put']",
      visible: false,
    )
  end

  it 'initializes form with configuration values' do
    expect(rendered).to have_field(
      t('two_factor_authentication.piv_cac.nickname'),
      with: nickname,
    )
  end

  it 'has labelled form with button to delete configuration' do
    expect(rendered).to have_button_to_with_accessibility(
      t('two_factor_authentication.piv_cac.delete'),
      piv_cac_path(id: configuration.id),
    )
  end
end
