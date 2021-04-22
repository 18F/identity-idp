require 'rails_helper'

describe 'idv/session_errors/_throttled.html.erb' do
  let(:sp_name) { nil }
  let(:extra_options) { nil }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)

    render 'idv/session_errors/throttled', extra_options: extra_options
  end

  context 'without an SP' do
    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).not_to have_link(href: return_to_sp_cancel_path)
    end
  end

  context 'with an SP' do
    let(:sp_name) { 'Example SP' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app: APP_NAME),
        href: MarketingSite.contact_url,
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end

  describe 'extra_options' do
    context 'without extra options' do
      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.contact_support', app: APP_NAME),
          href: MarketingSite.contact_url,
        )
      end
    end

    context 'with extra options' do
      let(:extra_options) { [{ text: 'Example', url: '#example' }] }

      it 'renders a list of troubleshooting options' do
        expect(rendered).to have_link('Example', href: '#example')
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.contact_support', app: APP_NAME),
          href: MarketingSite.contact_url,
        )
      end
    end
  end
end
