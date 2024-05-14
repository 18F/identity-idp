require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on static pages', :js do
  scenario 'not found page', allow_browser_log: true do
    visit '/non_existent_page'

    expect_page_to_have_no_accessibility_violations(page)
  end

  scenario 'other static error pages' do
    static_pages = [
      '/401',
      '/406',
      '/422',
      '/429',
      '/500',
    ]

    aggregate_failures do
      static_pages.each do |path|
        visit path

        expect_page_to_have_no_accessibility_violations(page)
      end
    end
  end
end
