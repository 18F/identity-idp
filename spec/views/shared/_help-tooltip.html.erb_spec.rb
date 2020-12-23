require 'rails_helper'

describe 'shared/_help-tooltip.html.erb' do
  it 'renders with block as USWDS tooltip' do
    tooltip_text = 'foobar'
    render('shared/help-tooltip') { tooltip_text }

    expect(rendered).to have_css(".help-tooltip__button[title='#{tooltip_text}']")
  end
end
