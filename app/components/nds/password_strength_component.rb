# frozen_string_literal: true

module NDS
  # Net-new NDS password strength meter, rendered only in the NDS bucket. Emits
  # the host lg-nds-password-strength.password-strength (with data-score and
  # data-open, hidden by default) wrapping __inner/__row/__track/__bar/__feedback
  # elements. The default PasswordStrengthComponent is unaffected; this variant is
  # only rendered on NDS pages.
  class PasswordStrengthComponent < BaseComponent
    attr_reader :input_id, :forbidden_passwords, :minimum_length, :tag_options

    def initialize(
      input_id:,
      minimum_length: Devise.password_length.min,
      forbidden_passwords: [],
      **tag_options
    )
      @input_id = input_id
      @minimum_length = minimum_length
      @forbidden_passwords = forbidden_passwords
      @tag_options = tag_options
    end

    def css_class
      ['password-strength', *tag_options[:class]]
    end

    def feedback_id
      "#{input_id}-password-strength"
    end
  end
end
