require 'rails_helper'

RSpec.describe 'idv/by_mail/enter_code_rate_limited/index.html.erb' do
  let(:sp_name) { nil }
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:decorated_sp_session).and_return(
      instance_double(ServiceProviderSession, sp_name: sp_name),
    )
    @expires_at = 6.hours.from_now

    render
  end

  it 'renders the heading and legacy exit link' do
    expect(rendered).to have_css('h1', text: t('idv.failure.gpo.rate_limited.heading'))
    expect(rendered).to have_link(
      t('idv.failure.exit.without_sp', app_name: APP_NAME),
      href: return_to_sp_failure_to_proof_path(step: 'verify_address', location: 'index'),
    )
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the return-home exit as the primary action above troubleshooting' do
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--tertiary)',
        text: t('nds.errors.return_home'),
      )
      expect(rendered).not_to have_css('.auth__form-page-body strong a')
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a.usa-button--tertiary[target=_blank]',
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
    end

    context 'with an SP' do
      let(:sp_name) { 'Example SP' }

      it 'uses the return-to-SP copy for the primary action' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button',
          text: t('idv.failure.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        )
      end
    end
  end
end
