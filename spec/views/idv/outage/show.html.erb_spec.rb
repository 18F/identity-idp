require 'rails_helper'

describe 'idv/outage/show.html.erb' do
  let(:exit_url) { '/exit' }
  let(:sp) { nil }

  subject(:rendered) { render }

  before do
    assign(:exit_url, exit_url)
    assign(:sp, sp)
  end

  it 'sets a title' do
    expect(view).to receive(:title).with(t('idv.titles.outage'))
    render
  end
  it 'has an h1' do
    expect(rendered).to have_selector('h1', text: t('idv.titles.outage'))
  end
  it 'links to the status page in a new window' do
    expect(rendered).to have_selector('a[target=_blank]', text: t('idv.outage.status_page_link'))
  end
  it 'renders an exit button' do
    expect(rendered).to have_selector('a', text: t('idv.outage.exit_button', app_name: APP_NAME))
  end
  it 'does not render any l13n markers' do
    expect(rendered).not_to include('%{')
  end

  context 'with sp' do
    let(:sp) { 'Department of Ice Cream' }
    it 'renders the explanation with the sp name' do
      expect(rendered).to include(sp)
    end
  end
end
