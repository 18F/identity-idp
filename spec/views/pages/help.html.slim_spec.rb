require 'rails_helper'

describe 'pages/help.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.help'))

    render
  end

  it 'does not contain any improperly-escaped HTML' do
    render

    expect(rendered).to_not include('&lt;')
    expect(rendered).to_not include('&gt;')
  end

  it 'is not missing any interpolation keys' do
    render

    missing_interpolation_keys = rendered.scan(/%\{[^\}]+\}/)

    expect(missing_interpolation_keys).to be_empty
  end
end
