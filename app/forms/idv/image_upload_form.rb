module Idv
  class ImageUploadForm
    include ActiveModel::Model

    ATTRIBUTES = %i[image].freeze

    attr_accessor :image

    validates :image, presence: true

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Image')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    def extra_analytics_attributes
      { is_fallback_link: image.present? }
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
