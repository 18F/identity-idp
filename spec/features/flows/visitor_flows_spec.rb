require 'rails_helper'

feature 'Visitors requesting login.gov directly', devise: true, user_flow: true do
  context 'when visiting the homepage' do
    before do
      visit root_path
    end

    it 'loads the home page' do
      Capybara::Screenshot.screenshot_and_save_page
    end

    context 'when choosing create account' do
      before do
        click_link t('links.create_account')
      end

      it 'informs the user about login.gov' do
        Capybara::Screenshot.screenshot_and_save_page
      end

      context 'when creating account with valid email' do
        before do
          sign_up_with(Faker::Internet.safe_email)
        end

        it 'notifies user to check email' do
          Capybara::Screenshot.screenshot_and_save_page
        end

        context 'when confirming email' do
          before do
            confirm_last_user
          end

          it 'prompts user to set password' do
            Capybara::Screenshot.screenshot_and_save_page
          end
        end
      end

      context 'when attempting with an invalid email' do
        before do
          sign_up_with('kevin@kevin')
        end

        it 'informs the user to try again' do
          Capybara::Screenshot.screenshot_and_save_page
        end
      end
    end
  end
end
