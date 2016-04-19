module SecurityQuestionPopulator
  def self.populate_security_questions
    questions = Rails.application.secrets.security_questions

    questions.each do |question|
      SecurityQuestion.find_or_create_by!(question: question)
    end
  end
end
