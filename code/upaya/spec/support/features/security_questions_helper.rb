module Features
  module SecurityQuestionsHelper
    def active_questions
      SecurityQuestion.where(active: true).pluck(:question)
    end

    def question_dropdown_ids
      all(:xpath, "//select[contains(@name, '[security_answers_attributes]')]").map { |s| s[:id] }
    end

    def answer_field_ids
      all(:xpath, "//input[contains(@name, '[security_answers_attributes]')]").
        map { |s| s[:id] }.select { |id| id.include?('text') }
    end

    def fill_in_security_answers
      question_dropdown_ids.each_with_index { |id, index| select active_questions[index], from: id }
      answer_field_ids.each { |id| fill_in id, with: 'answer' }
    end

    def answer_security_questions_with(answer)
      answer_field_ids.each { |id| fill_in id, with: answer }
    end
  end
end
