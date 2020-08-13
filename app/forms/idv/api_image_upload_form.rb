module Idv
  class ApiImageUploadForm
    include ActiveModel::Model
    include ActionView::Helpers::TranslationHelper

    IMAGE_KEYS = %i[
      front
      back
      selfie
    ].freeze

    validates_presence_of :front
    validates_presence_of :back
    validates_presence_of :selfie, if: :liveness_checking_enabled?

    validate :validate_images

    def initialize(params, liveness_checking_enabled:)
      @params = params
      @liveness_checking_enabled = liveness_checking_enabled
    end

    # Normally we'd return FormResponse, but that has errors as a hash,
    # where the proofer reponses have errors as an array. This is easier to compare
    # with the proofer responses
    # @return [DocAuthClient::Response]
    def submit
      DocAuthClient::Response.new(
        success: valid?,
        errors: errors.full_messages,
      )
    end

    def liveness_checking_enabled?
      @liveness_checking_enabled
    end

    IMAGE_KEYS.each do |image_key|
      define_method(image_key) do
        params[image_key]
      end
    end

    def self.human_attribute_name(attr, options = {})
      # i18n-tasks-use t('doc_auth.headings.front')
      # i18n-tasks-use t('doc_auth.headings.back')
      # i18n-tasks-use t('doc_auth.headings.selfie')
      I18n.t(attr, options.merge(scope: 'doc_auth.headings'))
    end

    private

    attr_reader :params

    def validate_images
      IMAGE_KEYS.each do |image_key|
        if params[image_key] && !valid_image?(params[image_key])
          errors.add(image_key, t('doc_auth.errors.invalid_image_url'))
        end
      end
    end

    def valid_image?(data_url)
      image = Idv::DataUrlImage.new(data_url)
      image.content_type.start_with?('image/') && image.read.present?
    end
  end
end
