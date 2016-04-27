require 'rails_helper'
require 'security_question_populator'

describe SecurityQuestionPopulator do
  before do
    SecurityQuestion.find_each(&:destroy)

    allow(Rails.application.secrets).to receive(:security_questions).
      and_return(['Hello?', 'What is your name?', 'Who are you?'])
  end

  describe '#populate_security_questions', questions: true do
    it 'creates new security questions' do
      expect { SecurityQuestionPopulator.populate_security_questions }.
        to change { SecurityQuestion.count }.by(3)
    end
  end
end
