require 'rails_helper'

describe 'shared/_block_link.html.erb' do
  it 'renders a link to the given URL with the given text' do
    render('shared/block_link', url: '/example') { 'Link Text' }

    expect(rendered).to have_selector('a[href="/example"]')
    expect(rendered).to have_content('Link Text')
  end
end
