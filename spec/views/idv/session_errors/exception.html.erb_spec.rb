require 'rails_helper'

describe 'idv/session_errors/exception.html.erb' do
  let(:sp_name) { nil }
  let(:sp_issuer) { nil }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enabled_issuers) { [] }
  let(:try_again_path) { '/example/path' }
  let(:in_person_flow) { false }

  before do
    decorated_session = instance_double(
      ServiceProviderSessionDecorator,
      sp_name: sp_name,
      sp_issuer: sp_issuer,
    )
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled_issuers).
      and_return(in_person_proofing_enabled_issuers)

    assign(:try_again_path, try_again_path)
    assign(:in_person_flow, in_person_flow)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: MarketingSite.contact_url,
    )
  end

  it 'does not render an in person proofing link' do
    expect(rendered).not_to have_link(href: idv_in_person_url)
  end

  context 'with in person proofing enabled' do
    let(:in_person_proofing_enabled) { true }

    it 'renders an in person proofing link' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.verify_in_person'),
        href: idv_in_person_url,
      )
    end

    context 'while already in in-person flow' do
      let(:in_person_flow) { true }

      it 'does not render an in person proofing link' do
        expect(rendered).not_to have_link(href: idv_in_person_url)
      end
    end
  end

  context 'with associated service provider' do
    let(:sp_name) { 'Example SP' }
    let(:sp_issuer) { 'example-issuer' }

    it 'renders a list of troubleshooting options' do
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'exception'),
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        href: MarketingSite.contact_url,
      )
    end

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it 'does not render an in person proofing link' do
        expect(rendered).not_to have_link(href: idv_in_person_url)
      end

      context 'with in person proofing enabled for service provider' do
        let(:in_person_proofing_enabled_issuers) { [sp_issuer] }

        it 'renders an in person proofing link' do
          expect(rendered).to have_link(
            t('idv.troubleshooting.options.verify_in_person'),
            href: idv_in_person_url,
          )
        end
      end
    end
  end
end
