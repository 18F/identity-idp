require 'rails_helper'

RSpec.describe 'idv/unavailable/show.html.erb' do
  let(:sp_name) { nil }
  subject(:rendered) { render }

  before do
    allow(view).to receive(:decorated_sp_session).and_return(
      instance_double(ServiceProviderSession, sp_name: sp_name),
    )
  end

  it 'sets a title' do
    expect(view).to receive(:title).with(t('idv.titles.unavailable'))
    render
  end
  it 'has an h1' do
    expect(rendered).to have_selector('h1', text: t('idv.titles.unavailable'))
  end
  it 'links to the status page in a new window' do
    expect(rendered).to have_selector(
      'a[target=_blank]',
      text: t('idv.unavailable.status_page_link'),
    )
  end

  describe('exit button') do
    it 'is rendered' do
      expect(rendered).to have_selector(
        'a',
        text: t('idv.unavailable.exit_button', app_name: APP_NAME),
      )
    end
    it 'links to the right place' do
      expect(rendered).to have_link(
        t('idv.unavailable.exit_button', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path(location: 'unavailable'),
      )
    end
  end

  it 'does not render any l13n markers' do
    expect(rendered).not_to include('%{')
  end

  context 'with sp' do
    let(:sp_name) { 'Department of Ice Cream' }
    it 'renders the explanation with the sp name' do
      expect(rendered).to include(sp_name)
    end
  end
end
