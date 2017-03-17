require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on static pages', :js do
  scenario 'not found page' do
    visit '/non_existent_page'

    expect(page).to be_accessible
  end

  scenario '401 page' do
    visit '/401'

    expect(page).to be_accessible
  end

  scenario '422 page' do
    visit '/422'

    expect(page).to be_accessible
  end

  scenario '429 page' do
    visit '/429'

    expect(page).to be_accessible
  end

  scenario '500 page' do
    visit '/500'

    expect(page).to be_accessible
  end
end
