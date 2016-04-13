# extends recoverable
module Devise
  mattr_accessor :max_security_questions_attempts
  module Models
    module Recoverable
      extend ActiveSupport::Concern

      def confirm_security_questions_answered
        reset_security_questions_attempts
        self.security_questions_answered_at = Time.now.utc
        save(validate: false)
      end

      def send_reset_password_instructions
        if !security_questions_attempts_exceeded?
          token = set_reset_password_token
          send_reset_password_instructions_notification(token)

          token
        else
          UserMailer.security_questions_attempts_exceeded(self).deliver_later
        end
      end

      def matching_answer?(provided_answer)
        security_answers.any? { |ans| ans.match_params?(provided_answer) }
      end

      def check_security_question_answer(provided_answer, question_index)
        return if matching_answer?(provided_answer)
        errors.add(:base, "Answer #{question_index} does not match.")
      end

      def check_security_question_answers(provided_answers)
        if security_questions_attempts_exceeded?
          errors.add(:base, I18n.t('errors.messages.max_security_questions_attempts'))
        else
          provided_answers.each_with_index do |provided_answer, i|
            check_security_question_answer(provided_answer, i + 1)
          end
        end
      end

      def security_questions_attempts_exceeded?
        security_question_attempts_count >= Devise.max_security_questions_attempts
      end

      def increase_security_questions_attempts
        update(security_question_attempts_count: security_question_attempts_count + 1)
      end

      def reset_security_questions_attempts
        update(security_question_attempts_count: 0)
      end
    end
  end
end
