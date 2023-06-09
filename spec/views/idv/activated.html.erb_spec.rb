require 'rails_helper'

RSpec.describe 'idv/activated.html.erb' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('idv.titles.activated'))

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_selector('h1', text: t('idv.titles.activated'))
  end
end
