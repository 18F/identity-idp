module IdvHelper
  def mock_idv_questions
    @_mock_idv_questions ||= Proofer::Vendor::Mock.new.build_question_set(nil)
  end

  # rubocop:disable Rails/DynamicFindBy
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
  # rubocop:enable Rails/DynamicFindBy

  def fill_out_idv_form_ok
    fill_in 'profile_first_name', with: 'Some'
    fill_in 'profile_last_name', with: 'One'
    fill_in 'profile_ssn', with: '666661234'
    fill_in 'profile_dob', with: '01/02/1980'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_idv_form_fail
    fill_in 'profile_first_name', with: 'Bad'
    fill_in 'profile_last_name', with: 'User'
    fill_in 'profile_ssn', with: '6666'
    fill_in 'profile_dob', with: '01/02/1900'
    fill_in 'profile_address1', with: '123 Main St'
    fill_in 'profile_city', with: 'Nowhere'
    select 'Kansas', from: 'profile_state'
    fill_in 'profile_zipcode', with: '66044'
  end

  def fill_out_financial_form_ok
    find('#idv_finance_form_finance_type_ccn').set(true)
    fill_in :idv_finance_form_ccn, with: '12345678'
  end

  def fill_out_phone_form_ok(phone = '415-555-0199')
    fill_in :idv_phone_form_phone, with: phone
  end

  def complete_idv_profile_ok(user)
    fill_out_idv_form_ok
    click_button t('forms.buttons.continue')
    fill_out_financial_form_ok
    click_button t('forms.buttons.continue')
    fill_out_phone_form_ok(user.phone)
    click_button t('forms.buttons.continue')
    fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
    click_submit_default
  end

  def click_acknowledge_recovery_code
    click_button t('forms.buttons.continue')
  end

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(subject.user_session, user)
    idv_session.vendor = :mock
    idv_session.applicant = applicant
    idv_session.resolution = resolution
    idv_session.profile_id = profile.id
    idv_session.question_number = 0
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  # rubocop:disable Rails/DynamicFindBy
  def complete_idv_session(answer_correctly)
    Proofer::Vendor::Mock::ANSWERS.each do |ques, answ|
      resolution.questions.find_by_key(ques).answer = answer_correctly ? answ : 'wrong'
      subject.idv_session.question_number += 1
    end
  end
  # rubocop:enable Rails/DynamicFindBy
end
