require 'rails_helper'
require 'axe-rspec'

feature 'Accessibility on static pages', :js do
  scenario 'not found page', allow_browser_log: true do
    visit '/non_existent_page'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario '401 page' do
    visit '/401'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario '406 page' do
    visit '/406'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario '422 page' do
    visit '/422'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario '429 page' do
    visit '/429'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end

  scenario '500 page' do
    visit '/500'

    expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
    expect(page).to label_required_fields
    expect(page).to be_uniquely_titled
  end
end
