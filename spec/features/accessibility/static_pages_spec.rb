require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on static pages', :js do
  scenario 'not found page', allow_browser_log: true do
    visit '/non_existent_page'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '401 page' do
    visit '/401'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '406 page' do
    visit '/406'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '422 page' do
    visit '/422'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '429 page' do
    visit '/429'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario '500 page' do
    visit '/500'

    expect_page_to_have_no_accessibility_violations(page)
  end
end
