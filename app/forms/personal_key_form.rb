class PersonalKeyForm
  include ActiveModel::Model
  include PersonalKeyValidator

  attr_accessor :personal_key

  def initialize(user, personal_key = nil)
    @user = user
    @personal_key = personal_key
  end

  def submit
    @success = valid_personal_key?

    UpdateUser.new(user: user, attributes: { personal_key: nil }).call if success

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :success

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'personal key',
    }
  end
end
