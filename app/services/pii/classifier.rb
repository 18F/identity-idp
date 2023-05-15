# frozen_string_literal: true

module Pii
  class Classifier
    # @param [Pii::Attributes] pii
    # @param [Proc] block A proc operate on pii
    # @return [Boolean|Object]
    def self.classify(user_info, &block)
      block.call(user_info)
    end

    # @param [String] user_email
    # @return [boolean] whether it is for test request logging
    def self.user_for_test_request_logging?(user_email)
      return false unless IdentityConfig.store.in_person_verify_test_logging_enabled
      return false if user_email.to_s.empty?
      regex = IdentityConfig.store.in_person_verify_test_logging_user_email_regex
      !!regex&.match?(user_email.strip)
    end
  end
end
