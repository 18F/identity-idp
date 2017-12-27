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

    if success
      UpdateUser.new(user: user, attributes: { personal_key: nil }).call
    else
      reset_sensitive_fields
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :success

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end

  def reset_sensitive_fields
    self.personal_key = nil
  end
end
