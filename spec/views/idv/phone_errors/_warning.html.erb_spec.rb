require 'rails_helper'

RSpec.describe 'idv/phone_errors/_warning.html.erb' do
  let(:sp_name) { nil }
  let(:text) { 'A problem occurred' }
  let(:assigns) { {} }

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)

    render('idv/phone_errors/warning', assigns) { text }
  end

  it 'renders heading' do
    expect(rendered).to have_css('h1', text: t('idv.failure.phone.heading'))
  end

  it 'renders link to try again' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: idv_phone_path)
  end

  it 'renders block text' do
    expect(rendered).to have_text(text)
  end

  describe 'contact_support_option' do
    context 'without contact support option' do
      it 'renders a list of troubleshooting options' do
        expect(rendered).not_to have_link(
          t('idv.troubleshooting.options.contact_support'),
          href: contact_redirect_url,
        )
      end
    end

    context 'with contact support option' do
      let(:assigns) { { contact_support_option: true } }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
          href: contact_redirect_url,
        )
      end
    end
  end
end
