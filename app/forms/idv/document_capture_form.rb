module Idv
  class DocumentCaptureForm
    include ActiveModel::Model

    ATTRIBUTES = %i[front_image
                    back_image
                    selfie_image].freeze

    attr_accessor :front_image,
                  :back_image,
                  :selfie_image
    attr_reader :liveness_checking_enabled

    validates :front_image, presence: true
    validates :back_image, presence: true
    validates :selfie_image, presence: true, if: :liveness_checking_enabled

    def initialize(**args)
      @liveness_checking_enabled = args.delete(:liveness_checking_enabled)
    end

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Image')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    def extra_analytics_attributes
      is_fallback_link = front_image.present? || back_image.present? || selfie_image.present?
      { is_fallback_link: is_fallback_link }
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
