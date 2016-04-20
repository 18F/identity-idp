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
end
