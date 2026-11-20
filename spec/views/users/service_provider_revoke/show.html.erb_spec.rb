require 'rails_helper'

RSpec.describe 'users/service_provider_revoke/show.html.erb' do
  let(:service_provider) { create(:service_provider, friendly_name: 'Test Agency') }
  let(:page) { Capybara.string(rendered) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    # The legacy form recalls sp_id from the current request, as on the real route.
    controller.request.path_parameters[:sp_id] = service_provider.id.to_s
    @service_provider = service_provider
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.revoke_consent'))

    render
  end

  context 'in the default layout' do
    it 'renders the legacy heading, description and actions' do
      render

      expect(page).to have_css('h1', text: t('titles.revoke_consent'))
      expect(page).to have_content(
        strip_tags(
          t(
            'account.revoke_consent.longer_description_html',
            service_provider_html: service_provider.friendly_name,
          ),
        ),
      )
      revoke_path = "/account/service_providers/#{service_provider.id}/revoke"
      expect(page).to have_css(
        "form[action$='#{revoke_path}'] [name=_method][value=delete]",
        visible: :all,
      )
      expect(page).to have_button(t('forms.buttons.continue'))
      expect(page).to have_link(t('links.cancel'), href: account_connected_services_path)
    end

    it 'does not render the NDS form page' do
      render

      expect(page).not_to have_css('.auth--form-page')
    end
  end

  context 'in the NDS layout' do
    before { allow(view).to receive(:nds_layout?).and_return(true) }

    it 'asks for the signed-in header' do
      render

      expect(view.content_for(:nds_account_header)).to eq('true')
    end

    it 'renders the disconnect heading and description for the agency' do
      render

      expect(page).to have_css('h1', count: 1)
      expect(page).to have_css(
        '.auth--form-page h1',
        text: t('nds.dashboard_home.revoke_heading', sp_name: service_provider.display_name),
      )
      expect(page).to have_css(
        '.auth__intro-description',
        text: t(
          'nds.dashboard_home.revoke_description',
          sp_name: service_provider.display_name,
          app_name: APP_NAME,
        ),
      )
    end

    it 'renders the destructive disconnect button deleting the same consent' do
      render

      form = page.find(
        "form[action='#{service_provider_revoke_url(sp_id: service_provider.id)}']",
      )
      expect(form).to have_css('[name=_method][value=delete]', visible: :all)
      expect(form).to have_button(
        t('account.revoke_consent.link_title'),
        class: %w[usa-button usa-button--danger],
      )
    end

    it 'renders a secondary cancel button back to the connected services page' do
      render

      expect(page).to have_link(
        t('links.cancel'),
        href: account_connected_services_path,
        class: %w[usa-button usa-button--secondary],
      )
      expect(page).not_to have_button(t('forms.buttons.continue'))
    end
  end
end
