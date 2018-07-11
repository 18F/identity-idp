module TwoFactorAuthentication
  class TotpSetupForm < SetupForm
    attr_accessor :code, :secret

    def submit
      success = valid? && valid_totp_code?

      process_valid_submission if success

      FormResponse.new(success: success, errors: {})
    end

    private

    def valid_totp_code?
      configuration_manager.confirm_configuration(secret, code)
    end

    def process_valid_submission
      configuration_manager.save_configuration
    end
  end
end
