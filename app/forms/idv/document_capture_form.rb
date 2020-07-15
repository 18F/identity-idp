module Idv
  class DocumentCaptureForm
    include ActiveModel::Model

    ATTRIBUTES = %i[front_image front_image_data_url
                    back_image back_image_data_url
                    selfie_image selfie_image_data_url].freeze

    attr_accessor :front_image, :front_image_data_url,
                  :back_image, :back_image_data_url,
                  :selfie_image, :selfie_image_data_url

    validate :front_image_or_image_data_url_presence
    validate :back_image_or_image_data_url_presence
    validate :selfie_image_or_image_data_url_presence

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Image')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    private

    def front_image_or_image_data_url_presence
      return if front_image.present? || front_image_data_url.present?
      errors.add(:front_image, :blank)
    end

    def back_image_or_image_data_url_presence
      return if back_image.present? || back_image_data_url.present?
      errors.add(:back_image, :blank)
    end

    def selfie_image_or_image_data_url_presence
      return if selfie_image.present? || selfie_image_data_url.present?
      errors.add(:selfie_image, :blank)
    end

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_image_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_image_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid image attribute"
    end
  end
end
