module Voice
  class OtpController < ApplicationController
    NUMBER_OF_TIMES_USER_CAN_REPEAT_CODE = 5

    skip_before_action :verify_authenticity_token

    def show
      if code.blank?
        render nothing: true, status: :bad_request
        return
      end

      @message = message
      @action_url = action_url
    end

    protected

    def encrypted_code
      params[:encrypted_code].to_s
    end

    def code
      return unless encrypted_code.present?

      cipher.decrypt(encrypted_code)
    end

    def message
      t('voice.otp.message', code: code_with_pauses)
    end

    def code_with_pauses
      code.scan(/\d/).join(', ')
    end

    def repeat_count
      (params[:repeat_count].presence || NUMBER_OF_TIMES_USER_CAN_REPEAT_CODE).to_i
    end

    def action_url
      return if repeat_count <= 1

      BasicAuthUrl.build(
        voice_otp_url(
          encrypted_code: encrypted_code,
          repeat_count: repeat_count - 1
        )
      )
    end

    def cipher
      Gibberish::AES.new(Figaro.env.attribute_encryption_key)
    end
  end
end
