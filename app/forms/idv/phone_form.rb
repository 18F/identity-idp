module Idv
  class PhoneForm
    include ActiveModel::Model

    attr_reader :user, :phone, :other_phone

    validate :phone_is_a_valid_us_number

    def initialize(user:, previous_params:)
      previous_params ||= {}
      @user = user
      self.other_phone = initial_other_phone_value(previous_params[:other_phone])
      self.phone = initial_phone_value(previous_params[:phone], other_phone)
    end

    # :reek:DuplicateMethodCall
    def submit(params)
      self.other_phone = PhoneFormatter.format(params[:other_phone])

      self.phone = if params[:phone] == 'other'
                     other_phone
                   else
                     PhoneFormatter.format(params[:phone])
                   end
      success = valid?

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    def user_has_multiple_phone_numbers?
      @user.phone_configurations.many?
    end

    def phone_belongs_to_user?
      @user.phone_configurations.any? do |configuration|
        configuration.phone == phone
      end
    end

    private

    attr_writer :phone, :other_phone

    def initial_other_phone_value(other_phone)
      return PhoneFormatter.format(other_phone) if other_phone.present?
    end

    # :reek:FeatureEnvy
    def initial_phone_value(input_phone, other_phone)
      input_phone = other_phone if input_phone == 'other'

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
