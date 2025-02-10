require 'rails_helper'

RSpec.describe 'layouts/base.html.erb' do
  before do
    view.title = 'Example'
  end

  it 'includes expected OpenGraph metadata' do
    render

    expect(rendered).to have_css('meta[name="og:site_name"][content~=""]', visible: false)
  end
end
