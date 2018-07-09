module TwoFactorAuthentication
  class TotpVerifyForm < VerifyForm
    attr_accessor :code

    validates :code, presence: true

    def submit
      FormResponse.new(success: valid_totp_code?, errors: {}, extra: extra_analytics_attributes)
    end

    private

    def valid_totp_code?
      configuration_manager.authenticate(code)
    end

    def extra_analytics_attributes
      {
        multi_factor_auth_method: 'totp',
      }
    end
  end
end
