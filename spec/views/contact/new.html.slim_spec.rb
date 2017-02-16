require 'rails_helper'

describe 'contact/new.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.contact'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.contact'))
  end

  it 'includes call center info' do
    render

    expect(rendered).to have_content t('contact.call_center')
  end
end
