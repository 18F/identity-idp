class ApiImageUploadForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validates_presence_of :front_image
  validates_presence_of :back_image

  validate :validate_images

  IMAGE_KEYS = %i[
    front_image
    back_image
    selfie_image
  ].freeze

  def initialize(params)
    @params = params
  end

  # @return [FormResponse]
  def submit
    FormResponse.new(
      success: valid?,
      errors: errors.messages,
      extra: {}
    )
  end

  IMAGE_KEYS.each do |image_key|
    define_method(image_key) do
      params[image_key]
    end
  end

  private

  attr_reader :params

  def validate_images
    IMAGE_KEYS.each do |image_key|
      if params[image_key]
        errors.add(image_key, 'invalid image url') unless valid_image?(params[image_key])
      end
    end
  end

  def valid_image?(data_url)
    uri = URI(data_url)
    return false if uri.opaque.blank?

    content_type_encoding, data = uri.opaque.split(',')
    content_type, encoding = content_type_encoding.split(';')

    uri.scheme == 'data' &&
      content_type.start_with?('image/') &&
      (
        (encoding == 'base64' && Base64.decode64(data).present?) ||
        (!encoding && CGI.unescape(data).present?)
      )
  end
end
