require 'rails_helper'

describe 'shared/_progress_steps.html.slim' do
  it 'displays the correct number of step units' do
    render

    expect(rendered).to have_css('.step', count: 6)
  end
end
