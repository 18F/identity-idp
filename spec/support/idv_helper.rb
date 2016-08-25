module IdvHelper
  def mock_idv_questions
    @_mock_idv_questions ||= Proofer::Vendor::Mock.new.build_question_set(nil)
  end

  def complete_idv_questions_ok
    %w(city bear quest color speed).each do |answer_key|
      question = mock_idv_questions.find_by_key(answer_key)
      answer_text = Proofer::Vendor::Mock::ANSWERS[answer_key]
      choices = question.choices

      if choices.nil?
        fill_in :answer, with: answer_text
      else
        choice = choices.detect { |c| c.key == answer_text }
        el_id = "#choice_#{choice.key_html_safe}"
        find(el_id).set(true)
      end
      click_button 'Next'
    end
  end

  def complete_idv_questions_fail
    %w(city bear quest color speed).each do |answer_key|
      question = mock_idv_questions.find_by_key(answer_key)
      answer_text = Proofer::Vendor::Mock::ANSWERS[answer_key]
      choices = question.choices

      if choices.nil?
        fill_in :answer, with: 'wrong'
      else
        choice = choices.detect { |c| c.key == answer_text }
        el_id = "#choice_#{choice.key_html_safe}"
        find(el_id).set(true)
      end
      click_button 'Next'
    end
  end

  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Some'
    fill_in 'profile_last_name', with: 'One'
    fill_in 'profile_ssn', with: '666661234'
    fill_in 'profile_dob', with: '19800102'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_idv_form_fail
    fill_in 'profile_first_name', with: 'Bad'
    fill_in 'profile_last_name', with: 'User'
    fill_in 'profile_ssn', with: '6666'
    fill_in 'profile_dob', with: '19000102'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_financial_form_ok
    fill_in :ccn, with: '12345678'
  end

  def fill_out_phone_form_ok(phone = '123-456-7890')
    fill_in :phone, with: phone
  end
end
