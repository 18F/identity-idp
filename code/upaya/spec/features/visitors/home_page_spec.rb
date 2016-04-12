# Feature: Home page
#   As a visitor
#   I want to visit a home page
#   So I can learn more about the website
feature 'Home page' do
  # Scenario: Visit the home page
  #   Given I am a visitor
  #   When I visit the home page
  #   Then I see "Welcome"
  scenario 'visit the home page' do
    visit root_path
    expect(page).to have_content I18n.t 'upaya.headings.log_in'
    expect(page).to have_content I18n.t 'upaya.headings.visitors.new_account'
  end

  scenario 'visit the dashboard' do
    visit dashboard_index_path

    expect(page).to have_content I18n.t 'devise.failure.unauthenticated'
  end

  context 'has usability elements' do
    xit 'can skip to contents' do
      visit root_path
      expect(page).to have_content 'Skip to main content'
      click_link 'Skip to main content'
      expect(current_path).to eq(root_path)
    end
  end

  context 'small print' do
    before(:each) { visit root_path }

    xit 'links to Privacy Act Statement' do
      click_link 'Privacy Act Statement'
      expect(page).to have_content('The information and associated')
      expect(page).to have_link 'www.upaya.gov/privacy', href: 'https://www.upaya.gov/privacy'
      expect(current_path).to eq terms_path
    end

    xit 'links to Paperwork Reduction Act Reporting Burden' do
      click_link 'Paperwork Reduction Act Reporting Burden'
      expect(page).to have_content 'An agency may not conduct'
      expect(current_path).to eq terms_path
    end

    it 'links to Accessibility Policy' do
      expect(page).
        to have_link('Accessibility Policy', href: 'http://upaya.18f.gov/accessibility')
    end

    it 'links to Terms of Use' do
      skip 'waiting for OMB approval'
      click_link 'Terms of Use'
      expect(page).to have_content('Rules of Behavior')
      expect(current_path).to eq terms_path
    end
  end

  describe 'navigation links' do
    it 'links to root for Sign In link' do
      visit root_path
      expect(page).to have_link('Sign In', href: '/')
    end
  end
end
