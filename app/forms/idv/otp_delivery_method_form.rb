module Idv
  class OtpDeliveryMethodForm
    include ActiveModel::Model

    attr_reader :otp_delivery_preference

    validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }

    def submit(params)
      self.otp_delivery_preference = params[:otp_delivery_preference]
      FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
    end

    private

    attr_writer :otp_delivery_preference

    def extra_analytics_attributes
      {
        otp_delivery_preference: otp_delivery_preference,
      }
    end
  end
end
