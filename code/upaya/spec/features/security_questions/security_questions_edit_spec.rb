# Feature: Edit security questions
#   As a user
#   I want to edit my security questions
#   So I can reset my password if I forget it
feature 'Security Questions Edit' do
  context 'user has active questions' do
    let!(:user) { create(:user, :signed_up) }

    background do
      Bullet.enable = false
      sign_in_and_2fa_user(user)
      visit users_questions_path
    end

    after(:each) { Bullet.enable = true }

    scenario 'my chosen questions are selected' do
      user.security_answers.each_with_index do |answer, index|
        expect(page).to have_select(
          "user[security_answers_attributes][#{index}][security_question_id]",
          selected: answer.question
        )
      end
    end

    scenario 'user changes questions' do
      fill_in_security_answers
      select active_questions.last, from: question_dropdown_ids.last

      click_button 'Submit'

      visit users_questions_path

      user.reload
      user.security_answers.each_with_index do |answer, index|
        expect(page).to have_select(
          "user[security_answers_attributes][#{index}][security_question_id]",
          selected: answer.question
        )
      end
    end

    scenario 'user chooses duplicate questions' do
      fill_in_security_answers
      select active_questions.first, from: question_dropdown_ids.last

      click_button 'Submit'

      expect(page).to have_content 'has already been taken'
    end
  end

  context 'user has inactive questions' do
    let!(:user) { create(:user, :tfa_confirmed, :with_inactive_security_question) }

    background do
      Bullet.enable = false
      sign_in_and_2fa_user(user)
      visit users_questions_path
    end

    after(:each) { Bullet.enable = true }

    context 'user visits questions page' do
      it 'selects inactive questions that belong to the user' do
        user.security_answers.each_with_index do |answer, index|
          expect(page).to have_select(
            "user[security_answers_attributes][#{index}][security_question_id]",
            selected: answer.question
          )
        end
      end

      it 'does not show inactive questions that do not belong to user' do
        inactive_questions = SecurityQuestion.where(active: false).pluck(:question)

        question_dropdown_ids.each do |id|
          questions = find_field(id).all('option').map(&:text)
          if questions.include?('Who is your favorite superhero?')
            expect(questions & inactive_questions).to eq ['Who is your favorite superhero?']
          else
            expect(questions & inactive_questions).to eq []
          end
        end
      end
    end

    scenario 'user changes questions' do
      fill_in_security_answers
      select active_questions.last, from: question_dropdown_ids.last

      click_button 'Submit'

      visit users_questions_path

      user.reload
      user.security_answers.each_with_index do |answer, index|
        expect(page).to have_select(
          "user[security_answers_attributes][#{index}][security_question_id]",
          selected: answer.question
        )
      end
    end
  end
end
