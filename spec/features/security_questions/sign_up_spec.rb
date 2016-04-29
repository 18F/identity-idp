require 'rails_helper'

# Feature: Sign up
#   As a visitor
#   I want to sign up
#   So I can visit protected areas of the site
feature 'Sign Up' do
  let!(:user) { create(:user, :tfa_confirmed, account_type: :self) }

  background do
    sign_in_user(user)
    fill_in 'code', with: user.otp_code
    click_button 'Submit'
  end

  scenario 'user is redirected to the new security questions form after confirming 2fa' do
    expect(current_url).to eq users_questions_url
  end

  scenario 'new security questions view has a localized page title' do
    expect(page).to have_title t('upaya.titles.security_questions.new')
  end

  scenario 'new security questions view has a localized header text' do
    expect(page).to have_content t('devise.security_questions.header_text')
  end

  scenario 'new security questions view has a localized description' do
    expect(page).to have_content t('devise.security_questions.description')
  end

  scenario 'user is redirected to dashboard after entering valid security answers' do
    fill_in_security_answers

    click_button 'Submit'

    expect(current_url).to eq dashboard_index_url
  end

  scenario 'user sees success notice after entering valid security answers' do
    fill_in_security_answers

    click_button 'Submit'

    expect(page).to have_content t('upaya.notices.secret_questions_created')
  end

  scenario 'user must select unique questions' do
    fill_in_security_answers

    select active_questions[0], from: question_dropdown_ids.last

    click_button 'Submit'

    expect(current_url).to eq users_questions_url
    expect(page).to have_content t('upaya.errors.duplicate_questions')
    expect(page).to have_content 'has already been taken'
  end

  it 'displays an error message if any answer field is empty' do
    click_button 'Submit'

    expect(page).to have_content("can't be blank")
  end

  it 'displays an error message if any answer field is empty and JS is on', js: true do
    click_button 'Submit'

    expect(page).to have_content('Please fill in all required fields')
  end

  context 'new user must select from active questions' do
    it 'displays active questions' do
      question_dropdown_ids.each do |id|
        questions = find_field(id).all('option').map(&:text)

        expect(questions & active_questions).to_not be_empty
      end
    end

    it 'does not display inactive questions' do
      inactive_questions = SecurityQuestion.where(active: false).pluck(:question)

      question_dropdown_ids.each do |id|
        questions = find_field(id).all('option').map(&:text)

        expect(questions & inactive_questions).to eq []
      end
    end
  end
end
