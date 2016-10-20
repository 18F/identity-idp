require 'rails_helper'

feature 'Navigation links', devise: true do
  scenario 'view navigation links' do
    visit root_path
    expect(page).to have_content 'Log in'
  end
end
