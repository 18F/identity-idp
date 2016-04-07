module SecurityQuestionPopulator
  def populate_security_questions
    add_old_questions
    add_new_questions
    update_inactive_questions
  end

  def add_old_questions
    old_questions = I18n.t('devise.security_questions.question_array')

    old_questions.each_with_index do |old_question, index|
      SecurityQuestion.find_or_create_by!(question: old_question, old_index: index + 1)
    end
  end

  def add_new_questions
    new_questions = I18n.t('devise.security_questions.new_questions')

    new_questions.each do |question|
      SecurityQuestion.find_or_create_by!(question: question)
    end
  end

  def update_inactive_questions
    inactive_questions = I18n.t('devise.security_questions.inactive_questions')

    inactive_questions.each do |question|
      SecurityQuestion.find_by_question(question).update(active: false)
    end
  end
end
