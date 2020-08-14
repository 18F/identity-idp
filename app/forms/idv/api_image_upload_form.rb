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

    def front
      params[:front]
    end

    def back
      params[:back]
    end

    def selfie
      params[:selfie]
    end

    def self.human_attribute_name(attr, options = {})
      # i18n-tasks-use t('doc_auth.headings.document_capture_front')
      # i18n-tasks-use t('doc_auth.headings.document_capture_back')
      # i18n-tasks-use t('doc_auth.headings.document_capture_selfie')
      I18n.t("doc_auth.headings.document_capture_#{attr}", options)
    end

    private

    attr_reader :params

    def validate_images
      IMAGE_KEYS.each do |image_key|
        validate_image(image_key) if params[image_key]
      end
    end

    def validate_image(image_key)
      file = params[image_key]

      unless file.respond_to?(:content_type)
        errors.add(image_key, t('doc_auth.errors.not_a_file'))
        return
      end

      data = file.read
      file.rewind

      return if file.content_type.start_with?('image/') || data.empty?
      errors.add(image_key, t('doc_auth.errors.must_be_image'))
    end
  end
end
