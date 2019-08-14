module Idv
  class PhoneForm
    include ActiveModel::Model

    attr_reader :user, :phone

    validate :phone_is_a_valid_us_number

    def initialize(user:, previous_params:)
      previous_params ||= {}
      @user = user
      self.phone = initial_phone_value(previous_params[:phone]) unless user_has_multiple_phones?
    end

    # :reek:DuplicateMethodCall
    def submit(params)
      self.phone = PhoneFormatter.format(params[:phone])
      success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
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

    # :reek:FeatureEnvy
    def initial_phone_value(input_phone)
      return PhoneFormatter.format(input_phone) if input_phone.present?

      user_phone = MfaContext.new(user).phone_configurations.take&.phone
      return unless Phonelib.valid_for_country?(user_phone, 'US')
      PhoneFormatter.format(user_phone)
    end

    def phone_is_a_valid_us_number
      return if Phonelib.valid_for_country?(phone, 'US')

      errors.add(:phone, :must_have_us_country_code)
    end

    def extra_analytics_attributes
      {
        country_code: parsed_phone.country,
        area_code: parsed_phone.area_code,
      }
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end
  end
end
