require 'rails_helper'

RSpec.describe 'openid_connect/logout/confirm_logout.html.erb' do
  let(:service_provider_name) { nil }
  let(:logout_params) do
    {
      client_id: 'urn:gov:gsa:openidconnect:test',
      post_logout_redirect_uri: 'https://example.com/logout',
      state: 'abcdefghijklmnopqrstuvwxyz',
    }
  end

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:params, logout_params)
    assign(:service_provider_name, service_provider_name)
  end

  it 'sets a title' do
    expect(view).to receive(:title=).with(t('openid_connect.logout.heading', app_name: APP_NAME))
    render
  end

  it 'renders the heading' do
    expect(rendered).to have_selector(
      'h1',
      text: t('openid_connect.logout.heading', app_name: APP_NAME),
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
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('openid_connect.logout.heading', app_name: APP_NAME),
      )
    end

    it 'renders the info status icon above the heading and a divider above the actions' do
      expect(rendered).to have_selector(
        '.auth__header--with-media .nds-status-icon--info .usa-icon',
      )
      expect(rendered).to have_selector('.auth--form-page > hr.divider + .auth__actions')
    end

    it 'does not render the legacy illustration' do
      expect(rendered).to_not have_selector('img')
    end

    it 'renders the confirm button deleting the session with the logout params' do
      expect(rendered).to have_selector(
        "form[action='#{openid_connect_logout_path}'] [name=_method][value=delete]",
        visible: :all,
      )
      logout_params.each do |key, value|
        expect(rendered).to have_selector(
          "form[action='#{openid_connect_logout_path}'] input[name='#{key}'][value='#{value}']",
          visible: :all,
        )
      end
      expect(rendered).to have_selector(
        '.auth__actions button.usa-button:not(.usa-button--tertiary)',
        text: t('openid_connect.logout.confirm', app_name: APP_NAME),
      )
    end

    it 'renders the deny action as a tertiary link to the account page' do
      expect(rendered).to have_selector(
        ".auth__actions a.usa-button.usa-button--tertiary[href='#{account_path}']",
        text: t('openid_connect.logout.deny'),
      )
    end

    context 'with a service provider name' do
      let(:service_provider_name) { 'Example Service Provider' }

      it 'renders the heading naming the service provider' do
        expect(rendered).to have_selector(
          '.auth--form-page h1',
          text: t(
            'openid_connect.logout.heading_with_sp',
            app_name: APP_NAME,
            service_provider_name:,
          ),
        )
      end
    end
  end
end
