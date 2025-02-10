# frozen_string_literal: true

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
end
