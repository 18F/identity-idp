require 'rails_helper'

RSpec.describe 'idv/session_errors/state_id_warning.html.erb' do
  before do
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
      href: idv_doc_auth_return_to_sp_path,
    )
  end
end
