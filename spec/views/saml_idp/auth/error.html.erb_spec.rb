require 'rails_helper'

RSpec.describe 'saml_idp/auth/error.html.erb' do
  let(:saml_request_validator) do
    SamlRequestValidator.new(blank_cert: true).tap do |validator|
      validator.call(
        service_provider: nil,
        authn_context: [],
        nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
      )
    end
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:saml_request_validator, saml_request_validator)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('saml_idp.auth.error.title'))
    render
  end

  it 'renders the error messages' do
    expect(rendered).to have_selector('li', text: t('errors.messages.blank_cert_element_req'))
    expect(rendered).to have_selector(
      'li',
      text: t('errors.messages.unauthorized_service_provider'),
    )
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('.auth--form-page h1', text: t('saml_idp.auth.error.title'))
    end

    it 'renders the error status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider and each error message in a list' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
      expect(rendered).to have_selector('.auth__form-page-body ul.usa-list.text-left li', count: 2)
      expect(rendered).to have_selector(
        '.auth__form-page-body li',
        text: t('errors.messages.blank_cert_element_req'),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body li',
        text: t('errors.messages.unauthorized_service_provider'),
      )
    end

    it 'does not render any actions' do
      expect(rendered).to_not have_selector('.auth__actions')
    end
  end
end
