module Idv
  class PhoneForm
    include ActiveModel::Model

    attr_reader :user, :phone, :allowed_countries, :delivery_methods

    validate :validate_phone

    # @param [User] user
    # @param [Hash] previous_params
    # @param [Array<string>, nil] allowed_countries
    def initialize(user:, previous_params:, allowed_countries: nil, delivery_methods: nil)
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

    def phone_belongs_to_user?
      @user.phone_configurations.any? do |configuration|
        configuration.phone == phone
      end
    end

    private

    attr_writer :phone

    def initial_phone_value(input_phone)
      return input_phone if input_phone.present?

      user_phone = MfaContext.new(user).phone_configurations.take&.phone
      user_phone if valid_phone?(user_phone, phone_confirmed: true)
    end

    def validate_phone
      return if valid_phone?(phone, phone_confirmed: user_phone?(phone))

      errors.add(:phone, :must_have_us_country_code)
    end

    def valid_phone?(phone, phone_confirmed:)
      return false if !valid_phone_for_allowed_countries?(phone)
      PhoneNumberCapabilities.new(
        phone,
        phone_confirmed: phone_confirmed,
      ).supports_all?(delivery_methods)
    end

    def valid_phone_for_allowed_countries?(phone)
      if allowed_countries.present?
        allowed_countries.all? { |country| Phonelib.valid_for_country?(phone, country) }
      else
        Phonelib.valid?(phone)
      end
    end

    def user_phone?(phone)
      MfaContext.new(user).phone_configurations.any? { |config| config.phone == phone }
    end

    def extra_analytics_attributes
      {
        country_code: parsed_phone.country,
        area_code: parsed_phone.area_code,
        pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]], # see errors.add(:phone)
      }
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end
  end
end
