module Idv
  class ImageUploadForm
    include ActiveModel::Model

    validates :image, presence: true

    ATTRIBUTES = [:image].freeze

    attr_accessor :image

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Image')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    private

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
