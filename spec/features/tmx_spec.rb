require 'rails_helper'

RSpec.describe 'TMX' do
  it 'fingerprints the device', js: true do
    visit 'https://mgh-device-id-demo.app.cloud.gov/'

    expect(page).to have_content('Email')

    fill_in 'email', with: 'test@example.com'
    fill_in 'firstName', with: 'Test'
    fill_in 'lastName', with: 'McTest'

    click_link_or_button 'Submit'

    expect(page).to have_selector('pre')

    raw_content = page.find('pre').text
    puts JSON.pretty_generate(JSON.parse(raw_content))
  end
end
