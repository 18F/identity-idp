require 'rails_helper'

describe 'pages/help.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.help'))

    render
  end
end
