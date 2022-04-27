module Idv
  class PhoneForm
    include ActiveModel::Model

    ALL_DELIVERY_METHODS = [:sms, :voice].freeze

    attr_reader :user, :phone, :allowed_countries, :delivery_methods, :international_code

    validate :validate_valid_phone_for_allowed_countries
    validate :validate_phone_delivery_methods

    # @param [User] user
    # @param [Hash] previous_params
    # @param [Array<String>, nil] allowed_countries
    # @param [Array<String>, nil] delivery_methods
    def initialize(
      user:,
      previous_params:,
      allowed_countries: nil,
      delivery_methods: ALL_DELIVERY_METHODS
    )
      previous_params ||= {}
      @user = user
      @allowed_countries = allowed_countries
      @delivery_methods = delivery_methods
      self.phone = initial_phone_value(previous_params[:phone]) unless user_has_multiple_phones?
    end

    def submit(params)
      self.phone = PhoneFormatter.format(params[:phone])
      success = valid?
      self.phone = params[:phone] unless success

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    def user_has_multiple_phones?
      @user.phone_configurations.many?
    end

    private

    attr_writer :phone

    def initial_phone_value(input_phone)
      initial_phone = input_phone
      initial_phone ||= begin
        user_phone = MfaContext.new(user).phone_configurations.take&.phone
        user_phone if valid_phone?(user_phone, phone_confirmed: true)
      end

      PhoneFormatter.format(initial_phone) if initial_phone
    end

    def validate_valid_phone_for_allowed_countries
      return if valid_phone_for_allowed_countries?(phone)

      if allowed_countries == ['US']
        errors.add(:phone, :must_have_us_country_code, type: :must_have_us_country_code)
      else
        errors.add(:phone, :improbable_phone, type: :improbable_phone)
      end
    end

    def validate_phone_delivery_methods
      return unless valid_phone_for_allowed_countries?(phone)

      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: user_phone?(phone))
      unsupported_delivery_methods(capabilities).each do |delivery_method|
        errors.add(
          :phone,
          I18n.t(
            "two_factor_authentication.otp_delivery_preference.#{delivery_method}_unsupported",
            location: capabilities.unsupported_location,
          ),
          type: :"#{delivery_method}_unsupported",
        )
      end
    end

    def valid_phone_for_allowed_countries?(phone)
      if allowed_countries.present?
        allowed_countries.all? { |country| Phonelib.valid_for_country?(phone, country) }
      else
        Phonelib.valid?(phone)
      end
    end

    def phone_info
      return @phone_info if defined?(@phone_info)

      if phone.blank? || !IdentityConfig.store.voip_check
        @phone_info = nil
      else
        @phone_info = Telephony.phone_info(phone)
      end
    rescue Aws::Pinpoint::Errors::TooManyRequestsException
      @warning_message = 'AWS pinpoint phone info rate limit'
      @phone_info = Telephony::PhoneNumberInfo.new(type: :unknown)
    rescue Aws::Pinpoint::Errors::BadRequestException
      errors.add(:phone, :improbable_phone, type: :improbable_phone)
      @phone_info = Telephony::PhoneNumberInfo.new(type: :unknown)
    end

    def valid_phone?(phone, phone_confirmed:)
      return false if !valid_phone_for_allowed_countries?(phone)
      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: phone_confirmed)
      unsupported_delivery_methods(capabilities).blank?
    end

    def unsupported_delivery_methods(capabilities)
      delivery_methods.select { |delivery_method| !capabilities.supports?(delivery_method) }
    end

    def user_phone?(phone)
      MfaContext.new(user).phone_configurations.any? { |config| config.phone == phone }
    end

    def extra_analytics_attributes
      {
        phone_type: phone_info&.type, # comes from pinpoint API
        types: parsed_phone.types, # comes from Phonelib gem
        carrier: phone_info&.carrier,
        country_code: parsed_phone.country,
        area_code: parsed_phone.area_code,
        pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]], # see errors.add(:phone)
      }.tap do |extra|
        extra[:warn] = @warning_message if @warning_message
      end
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end
  end
end
