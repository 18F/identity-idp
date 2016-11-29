require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on static pages', :js do
  scenario 'privacy page' do
    visit privacy_path

    expect(page).to be_accessible
  end

  scenario 'help page' do
    visit help_path

    expect(page).to be_accessible
  end

  pending 'not found page' do
    visit '/non_existent_page'

    expect(page).to be_accessible
  end
end
