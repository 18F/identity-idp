require 'rails_helper'

describe 'shared/_block_link.html.erb' do
  it 'raises an error if no block given' do
    expect { render 'shared/block_link', url: '/example' }.to raise_error('no block content given')
  end

  it 'renders a link to the given URL with the given text' do
    render('shared/block_link', url: '/example') { 'Link Text' }

    expect(rendered).to have_selector('a[href="/example"]')
    expect(rendered).to have_content('Link Text')
  end

  it 'renders a link in a new tab' do
    render('shared/block_link', url: '/example', new_tab: true) { 'Link Text' }

    expect(rendered).to have_selector('a[href="/example"][target="_blank"]')
    expect(rendered).to have_content('Link Text')
    expect(rendered).to have_content(t('links.new_window'))
  end
end
