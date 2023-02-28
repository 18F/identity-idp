module Idv
  class PhoneForm
    include ActiveModel::Model

    ALL_DELIVERY_METHODS = [:sms, :voice].freeze

    attr_reader :user, :phone, :allowed_countries, :delivery_methods, :international_code,
                :otp_delivery_preference

    validate :validate_valid_phone_for_allowed_countries
    validate :validate_phone_delivery_methods
    validates :otp_delivery_preference, inclusion: { in: %w[sms voice] }

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

      @international_code, @phone = determine_initial_values(
        **previous_params.
        symbolize_keys.
        slice(:international_code, :phone),
      )
    end

    def submit(params)
      self.phone = PhoneFormatter.format(params[:phone])
      self.otp_delivery_preference = params[:otp_delivery_preference]
      self.otp_delivery_preference = 'sms' if self.otp_delivery_preference.nil?
      success = valid?
      self.phone = params[:phone] unless success

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    private

    attr_writer :phone, :otp_delivery_preference

    # @return [Array<string,string>] The international_code and phone values to use.
    def determine_initial_values(international_code: nil, phone: nil)
      if phone.nil? && international_code.nil?
        default_phone = user.default_phone_configuration&.phone
        if valid_phone?(default_phone, phone_confirmed: true)
          phone = default_phone
          international_code = country_code_for(default_phone)
        end
      else
        international_code ||= country_code_for(phone)
      end

      phone = PhoneFormatter.format(phone, country_code: international_code)

      [international_code, phone]
    end

    def country_code_for(phone)
      Phonelib.parse(phone).country
    end

    def validate_valid_phone_for_allowed_countries
      return if valid_phone_for_allowed_countries?(phone)
      errors.add(:phone, :improbable_phone, type: :improbable_phone)
    end

    def validate_phone_delivery_methods
      return unless valid_phone_for_allowed_countries?(phone)

      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: user_phone?(phone))
      unsupported_methods = unsupported_delivery_methods(capabilities)
      return if unsupported_methods.count != delivery_methods.count
      unsupported_methods.each do |delivery_method|
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
        allowed_countries.any? { |country| Phonelib.valid_for_country?(phone, country) }
      else
        Phonelib.valid?(phone)
      end
    end

    def phone_info
      return @phone_info if defined?(@phone_info)

      if phone.blank? || !IdentityConfig.store.phone_service_check
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
        otp_delivery_preference: otp_delivery_preference,
      }.tap do |extra|
        extra[:warn] = @warning_message if @warning_message
      end
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end
  end
end
