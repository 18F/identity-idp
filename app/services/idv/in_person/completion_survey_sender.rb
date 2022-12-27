module Idv
  module InPerson
    class CompletionSurveySender
      ##
      # @param [User] user
      # @param [String] issuer
      def self.send_completion_survey(user, issuer)
        return unless user.should_receive_in_person_completion_survey?(issuer)

        user.confirmed_email_addresses.each do |email_address|
          UserMailer.with(user: user, email_address: email_address).in_person_completion_survey.
            deliver_now_or_later
        end

        user.mark_in_person_completion_survey_sent(issuer)
      end
    end
  end
end
