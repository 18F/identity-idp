module Idv
  class ImageUploadForm
    include ActiveModel::Model

    ATTRIBUTES = %i[image image_data_url].freeze

    attr_accessor :image, :image_data_url

    validate :image_or_image_data_url_presence

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Image')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages, extra: extra_hash)
    end

    private

    def extra_hash
      { is_fallback_link: image.present? }
    end

    def image_or_image_data_url_presence
      return if image.present? || image_data_url.present?
      errors.add(:image, :blank)
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
