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
    allow(view).to receive(:nds_layout?).and_return(false)
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

  it 'does not render the NDS manage page in the default layout' do
    expect(rendered).not_to have_css('.auth--form-page')
    expect(view.content_for?(:nds_account_header)).to eq(false)
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the Figma section heading in the signed-in header' do
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('headings.account.government_employee_id'),
      )
      expect(view.content_for?(:nds_account_header)).to eq(true)
    end

    it 'renders the nickname form, which still submits a PUT' do
      expect(rendered).to have_css(
        "form#manage-authenticator-form[action='#{piv_cac_path(id: configuration.id)}'] " \
        "input[name='_method'][value='put']",
        visible: false,
      )
      expect(rendered).to have_field(t('nds.piv_cac_setup.nickname'), with: nickname)
      expect(rendered).to have_css(
        "#manage-authenticator-form input.usa-input__control[name='form[name]']",
      )
    end

    it 'renders the save button for the nickname form' do
      expect(rendered).to have_css(
        "button[type='submit'][form='manage-authenticator-form'].usa-button",
        text: t('components.manageable_authenticator.save'),
      )
    end

    it 'renders the labelled delete button, which still submits a DELETE' do
      expect(rendered).to have_button_to_with_accessibility(
        t('components.manageable_authenticator.delete'),
        piv_cac_path(id: configuration.id),
        t('two_factor_authentication.piv_cac.delete'),
      )
      expect(rendered).to have_css(
        "form[action='#{piv_cac_path(id: configuration.id)}'] " \
        "input[name='_method'][value='delete']",
        visible: false,
      )
      expect(rendered).to have_css(
        'button.usa-button--tertiary.account__danger-action',
        text: t('components.manageable_authenticator.delete'),
      )
    end

    it 'does not render the legacy cancel link' do
      expect(rendered).not_to have_link(t('links.cancel'))
    end

    it 'ties a nickname error to the field' do
      message = t('errors.manage_authenticator.unique_name_error')
      form.errors.add(:name, :duplicate, message:)

      expect(rendered).to have_css(
        "input[aria-invalid='true'][aria-describedby~='form_name_nds_error']",
      )
      expect(rendered).to have_css('#form_name_nds_error', text: message)
    end
  end
end
