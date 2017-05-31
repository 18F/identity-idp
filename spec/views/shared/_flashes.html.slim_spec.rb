require 'rails_helper'

describe 'shared/_flashes.html.slim' do
  it 'renders nothing when flash key, but not message, is present' do
    allow(view).to receive(:flash).and_return(error: '')
    render

    expect(rendered).not_to have_selector('div[role="alert"]')
  end

  it 'renders a flash message when both key and value are present' do
    allow(view).to receive(:flash).and_return('error' => 'an error')
    render

    expect(rendered).to have_selector('div[role="alert"]')
  end
end
