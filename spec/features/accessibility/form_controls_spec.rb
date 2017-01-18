require 'rails_helper'

describe 'form controls are accessible', :js do
  it 'highlights show password when focused' do
    visit root_path
    checkbox = find('label.checkbox')

    # Indicator should not be highlighted on page load
    expect(checkbox).to_not have_css('span.indicator-focused')

    # Checkbox is focused, indicator should be focused
    page.evaluate_script('document.getElementById("pw-toggle-0").focus()')
    expect(checkbox).to have_css('span.indicator-focused')
    
    # Focus is moved off checkbox, indicator shouldn't have focus
    page.evaluate_script('document.getElementById("pw-toggle-0").blur()')
    expect(checkbox).to_not have_css('span.indicator-focused')
  end
end
