module TwoFactorAuthentication
  class PhoneVerifyForm < VerifyForm
    attr_accessor :code

    validates :code, presence: true

    def submit
      FormResponse.new(success: valid_direct_otp_code?, errors: {})
    end

    private

    def valid_direct_otp_code?
      configuration_manager.authenticate(code)
    end
  end
end
