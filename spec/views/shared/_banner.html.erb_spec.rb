require 'rails_helper'

describe 'shared/_banner.html.erb' do
  it 'properly HTML escapes the secure notification' do
    render

    expect(rendered).to_not have_content('<strong>')
  end
end
