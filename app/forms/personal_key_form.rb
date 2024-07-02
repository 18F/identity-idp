# frozen_string_literal: true

class PersonalKeyForm
  include ActiveModel::Model
  include PersonalKeyValidator

  attr_accessor :personal_key

  validate :check_personal_key

  def initialize(user, personal_key = nil)
    @user = user
    @personal_key = normalize_personal_key(personal_key)
  end

  def submit
    @success = valid?

    reset_sensitive_fields unless success

    FormResponse.new(success:, errors:)
  end

  private

  attr_reader :user, :success

  def reset_sensitive_fields
    self.personal_key = nil
  end
end
