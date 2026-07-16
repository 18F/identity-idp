# frozen_string_literal: true

class PasswordStrengthComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param minimum_length text
  # @param forbidden_passwords text
  def workbench(minimum_length: '12', forbidden_passwords: 'password')
  end
end
