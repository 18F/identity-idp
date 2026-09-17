require 'rails_helper'

RSpec.describe 'users/service_provider_inactive/index.html.erb' do
  let(:sp_name) { t('service_providers.errors.generic_sp_name') }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:sp_name, sp_name)
  end

  it 'renders heading' do
    expect(rendered).to have_css(
      'h1',
      text: t('service_providers.errors.inactive.heading', sp_name:, app_name: APP_NAME),
    )
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the form-page card with the inactive heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('service_providers.errors.inactive.heading', sp_name:, app_name: APP_NAME),
      )
    end

    it 'renders the error status-icon badge above the heading' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--error')
      expect(rendered).to have_selector('.nds-status-icon--error .usa-icon')
    end

    it 'renders a divider under the heading' do
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the instructions body copy' do
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('service_providers.errors.inactive.instructions', sp_name:, app_name: APP_NAME),
      )
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: t('service_providers.errors.inactive.instructions2'),
      )
    end

    it 'renders the return action button to the root path' do
      expect(rendered).to have_selector('.auth__actions')
      expect(rendered).to have_link(
        t('service_providers.errors.inactive.button_text', app_name: APP_NAME),
        href: root_path,
      )
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end

    context 'with a named service provider' do
      let(:sp_name) { 'Department of Ice Cream' }

      it 'renders the heading with the sp name' do
        expect(rendered).to have_selector('.auth--form-page h1', text: sp_name)
      end
    end
  end
end
