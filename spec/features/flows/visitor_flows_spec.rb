require 'rails_helper'

feature 'Visitors requesting login.gov directly', devise: true, user_flow: true do
  context 'when visiting the homepage' do
    before do
      visit root_path
    end

    it 'loads the home page' do
      screenshot_and_save_page
    end

    describe 'showing the password' do
      it 'allows me to see my password', js: true do
        visit new_user_session_path
        fill_in 'Password', with: 'my password'
        screenshot_and_save_page
      end
    end

    context 'when attempting to sign in' do
      context 'with a valid account' do
        before do
          @user = create(:user, :signed_up)
          fill_in 'Email', with: @user.email
          fill_in 'Password', with: @user.password
          page.find('.btn-primary').click
        end

        it 'sends OTP via previously chosen method' do
          screenshot_and_save_page
        end

        context 'with a valid OTP' do
          before do
            fill_in 'code', with: @user.reload.direct_otp
            click_button t('forms.buttons.submit.default')
          end

          it 'redirects to profile' do
            screenshot_and_save_page
          end
        end

        context 'with an invalid OTP submitted' do
          before do
            fill_in 'code', with: '123abc'
            click_button t('forms.buttons.submit.default')
          end

          it 'displays a useful error' do
            screenshot_and_save_page
          end

          context 'with a second invalid OTP submitted' do
            before do
              fill_in 'code', with: '123abc'
              click_button t('forms.buttons.submit.default')
            end

            it 'displays a useful error' do
              screenshot_and_save_page
            end

            context 'with a third invalid OTP submitted' do
              before do
                fill_in 'code', with: '123abc'
                click_button t('forms.buttons.submit.default')
              end

              it 'displays a useful error and locks the user account' do
                screenshot_and_save_page
              end
            end
          end
        end
      end

      context 'without valid credentials' do
        before do
          fill_in 'Email', with: Faker::Internet.safe_email
          fill_in 'Password', with: 'my password'
          page.find('.btn-primary').click
        end

        it 'displays a useful error message' do
          screenshot_and_save_page
        end
      end
    end

    context 'when choosing create account' do
      before do
        click_link t('links.create_account')
      end

      it 'informs the user about login.gov' do
        screenshot_and_save_page
      end

      context 'when creating account with valid email' do
        before do
          sign_up_with(Faker::Internet.safe_email)
        end

        it 'notifies user to check email' do
          screenshot_and_save_page
        end

        context 'when confirming email' do
          before do
            confirm_last_user
          end

          it 'prompts user to set password' do
            screenshot_and_save_page
          end
        end
      end

      context 'when attempting with an invalid email' do
        before do
          sign_up_with('kevin@kevin')
        end

        it 'informs the user to try again' do
          screenshot_and_save_page
        end
      end
    end
  end
end
