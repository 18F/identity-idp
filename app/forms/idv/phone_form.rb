module Idv
  class PhoneForm
    include ActiveModel::Model
    include FormPhoneValidator

    attr_reader :idv_params, :user, :phone
    attr_accessor :international_code

    def initialize(idv_params, user)
      @idv_params = idv_params
      @user = user
      self.phone = (idv_params[:phone] || user.phone).phony_formatted(
        format: :international, normalize: :US, spaces: ' '
      )
      self.international_code = PhoneFormatter::DEFAULT_COUNTRY
    end

    def submit(params)
      submitted_phone = params[:phone]

      formatted_phone = PhoneFormatter.new.format(submitted_phone, country_code: international_code)

      self.phone = formatted_phone

      success = valid?
      update_idv_params(formatted_phone) if success

      FormResponse.new(success: success, errors: errors.messages)
    end

    private

    attr_writer :phone

    def update_idv_params(phone)
      normalized_phone = phone.gsub(/\D/, '')[1..-1]
      idv_params[:phone] = normalized_phone

      return if phone != user.phone

      idv_params[:phone_confirmed_at] = user.phone_confirmed_at
    end
  end
end
