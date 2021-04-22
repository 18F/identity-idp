require 'rails_helper'

describe 'idv/phone_errors/_warning.html.erb' do
  let(:sp_name) { nil }
  let(:text) { 'A problem occurred' }
  let(:contact_support_option) { false }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render('idv/phone_errors/warning', contact_support_option: contact_support_option) do
      text
    end
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
          href: MarketingSite.contact_url,
        )
      end
    end

    context 'with contact support option' do
      let(:contact_support_option) { true }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.contact_support', app: APP_NAME),
          href: MarketingSite.contact_url,
        )
      end
    end
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).not_to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end
end
