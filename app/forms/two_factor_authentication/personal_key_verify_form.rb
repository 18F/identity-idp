module TwoFactorAuthentication
  class PersonalKeyVerifyForm < VerifyForm
    include PersonalKeyValidator

    attr_accessor :personal_key

    validates :personal_key, presence: true
    validate :check_personal_key

    def initialize(data)
      @user = data[:user]
      data[:personal_key] = normalize_personal_key(data[:personal_key])
      super(data)
    end

    def submit
      success = valid?
      extra = extra_analytics_attributes

      reset_sensitive_fields unless success

      FormResponse.new(success: success, errors: errors.messages, extra: extra)
    end

    private

    def extra_analytics_attributes
      {
        multi_factor_auth_method: 'personal key',
      }
    end

    def reset_sensitive_fields
      self.personal_key = nil
    end
  end
end
