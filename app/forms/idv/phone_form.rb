module Idv
  class PhoneForm
    include ActiveModel::Model
    include FormPhoneValidator

    attr_reader :idv_params, :user, :phone
    attr_accessor :international_code

    validate :phone_has_us_country_code

    def initialize(idv_params, user)
      @idv_params = idv_params
      @user = user
      self.phone = initial_phone_value(idv_params[:phone] || user.phone)
      self.international_code = PhoneFormatter::DEFAULT_COUNTRY
    end

    def submit(params)
      formatted_phone = PhoneFormatter.new.format(params[:phone])
      self.phone = formatted_phone

      success = valid?
      update_idv_params(formatted_phone) if success

      FormResponse.new(success: success, errors: errors.messages)
    end

    private

    attr_writer :phone

    def initial_phone_value(phone)
      formatted_phone = PhoneFormatter.new.format(
        phone, country_code: PhoneFormatter::DEFAULT_COUNTRY
      )
      return unless Phony.plausible? formatted_phone
      self.phone = formatted_phone
    end

    def phone_has_us_country_code
      country_code = Phonelib.parse(phone).country_code || '1'
      return if country_code == '1'

      errors.add(:phone, :must_have_us_country_code)
    end

    def update_idv_params(phone)
      normalized_phone = phone.gsub(/\D/, '')[1..-1]
      idv_params[:phone] = normalized_phone

      return idv_params[:phone_confirmed_at] = nil unless phone == user.phone
      idv_params[:phone_confirmed_at] = user.phone_confirmed_at
    end
  end
end
