require 'rails_helper'

RSpec.describe 'idv/session_errors/exception.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:try_again_path) { '/example/path' }

  before do
    decorated_sp_session = instance_double(
      ServiceProviderSession,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    assign(:try_again_path, try_again_path)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: contact_redirect_url,
    )
  end

  context 'with associated service provider' do
    let(:sp_name) { 'Example SP' }
    let(:sp_issuer) { 'example-issuer' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: contact_redirect_url,
      )
    end
  end
end
