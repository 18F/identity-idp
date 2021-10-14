require 'rails_helper'

describe 'idv/phone_errors/_warning.html.erb' do
  let(:sp_name) { nil }
  let(:text) { 'A problem occurred' }
  let(:assigns) { {} }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

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
          href: MarketingSite.contact_url,
        )
      end
    end

    context 'with contact support option' do
      let(:assigns) { { contact_support_option: true } }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
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
        href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'warning'),
      )
    end

    context 'without a name' do
      it 'renders failure to proof url with default location' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
          href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'warning'),
        )
      end
    end

    context 'with a name' do
      let(:assigns) { { name: 'fail' } }

      it 'renders failure to proof url with name as location' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
          href: return_to_sp_failure_to_proof_path(step: 'phone', location: 'fail'),
        )
      end
    end
  end
end
