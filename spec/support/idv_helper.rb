module IdvHelper
  def mock_idv_questions
    @_mock_idv_questions ||= Proofer::Vendor::Mock.new.build_question_set(nil)
  end

  def complete_idv_questions_ok
    %w(city bear quest color speed).each do |answer_key|
      question = mock_idv_questions.find_by_key(answer_key)
      answer_text = Proofer::Vendor::Mock::ANSWERS[answer_key]
      if question.choices.nil?
        fill_in :answer, with: answer_text
      else
        choice = question.choices.detect { |c| c.key == answer_text }
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
      if question.choices.nil?
        fill_in :answer, with: 'wrong'
      else
        choice = question.choices.detect { |c| c.key == answer_text }
        el_id = "#choice_#{choice.key_html_safe}"
        find(el_id).set(true)
      end
      click_button 'Next'
    end
  end

  def fill_out_idv_form_ok
    fill_in :first_name, with: 'Some'
    fill_in :last_name, with: 'One'
    fill_in :ssn, with: '666661234'
    fill_in :dob, with: '19800102'
    fill_in :address1, with: '123 Main St'
    fill_in :city, with: 'Nowhere'
    select 'Kansas', from: :state
    fill_in :zipcode, with: '66044'
  end

  def fill_out_idv_form_fail
    fill_in :first_name, with: 'Bad'
    fill_in :last_name, with: 'User'
    fill_in :ssn, with: '6666'
    fill_in :dob, with: '19000102'
    fill_in :address1, with: '123 Main St'
    fill_in :city, with: 'Nowhere'
    select 'Kansas', from: :state
    fill_in :zipcode, with: '66044'
  end
end
