require 'rails_helper'

describe 'verify/index.html.slim' do
  it 'displays the correct progress step' do
    render

    expect(rendered).to have_css('.step-4.active')
  end
end
