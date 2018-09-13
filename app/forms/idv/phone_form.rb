module Idv
  class PhoneForm
    include ActiveModel::Model

    attr_reader :idv_params, :user, :phone
    attr_accessor :international_code

    validate :phone_is_a_valid_us_number

    def initialize(idv_params, user)
      @idv_params = idv_params
      @user = user
      self.phone = initial_phone_value(idv_params[:phone] || user.phone_configurations.first&.phone)
      self.international_code = PhoneFormatter::DEFAULT_COUNTRY
    end

    def submit(params)
      formatted_phone = PhoneFormatter.format(params[:phone])
      self.phone = formatted_phone
      success = valid?
      update_idv_params(formatted_phone) if success

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_writer :phone

    def initial_phone_value(phone)
      formatted_phone = PhoneFormatter.format(phone)
      return unless Phonelib.valid_for_country?(formatted_phone, 'US')

      self.phone = formatted_phone
    end

    def phone_is_a_valid_us_number
      return if Phonelib.valid_for_country?(phone, 'US')

      errors.add(:phone, :must_have_us_country_code)
    end

    def update_idv_params(phone)
      normalized_phone = phone.gsub(/\D/, '')[1..-1]
      idv_params[:phone] = normalized_phone

      return idv_params[:phone_confirmed_at] = nil unless phone == formatted_user_phone
      idv_params[:phone_confirmed_at] = user.phone_configurations.first&.confirmed_at
    end

    def formatted_user_phone
      Phonelib.parse(user.phone_configurations.first&.phone).international
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone)
    end

    def extra_analytics_attributes
      {
        country_code: parsed_phone.country,
        area_code: parsed_phone.area_code,
      }
    end
  end
end
