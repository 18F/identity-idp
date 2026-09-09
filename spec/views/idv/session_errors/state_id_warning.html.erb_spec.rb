require 'rails_helper'

RSpec.describe 'idv/session_errors/state_id_warning.html.erb' do
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    assign(:try_again_path, '/try_again')

    render
  end

  it 'has a heading' do
    expect(rendered).to have_css('h1', text: t('idv.warning.state_id.heading'))
  end

  it 'shows explanation' do
    expect(rendered).to have_text(t('idv.warning.state_id.explanation'))
  end

  it 'shows next steps' do
    expect(rendered).to have_text(strip_tags(t('idv.warning.state_id.next_steps.preamble')))

    t('idv.warning.state_id.next_steps.items_html', app_name: APP_NAME).each do |item|
      expect(rendered).to have_text(strip_tags(item))
    end
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.warning.state_id.try_again_button'), href: '/try_again')
  end

  it 'shows exit login.gov button' do
    expect(rendered).to have_link(
      t('idv.warning.state_id.cancel_button', app_name: APP_NAME),
      href: return_to_sp_failure_to_proof_url(step: 'verify_info', location: 'state_id_warning'),
    )
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'shows the explanation and both actions without the next-steps list' do
      expect(rendered).to have_css(
        '.auth__form-page-body p',
        text: t('idv.warning.state_id.explanation'),
      )
      expect(rendered).not_to have_text(strip_tags(t('idv.warning.state_id.next_steps.preamble')))
      expect(rendered).not_to have_css('.auth__form-page-body ul')
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--secondary)',
        text: t('idv.warning.state_id.try_again_button'),
      )
      expect(rendered).to have_css(
        '.auth__actions a.usa-button--secondary',
        text: t('idv.warning.state_id.cancel_button', app_name: APP_NAME),
      )
    end
  end
end
