# frozen_string_literal: true

module Idv
  class IdvImage
    attr_reader :value, :type, :socure

    # @param type [Symbol] image type as described by IdvImages::TYPES
    # @param value [#read, String] an IO object or String that contains the raw image data
    def initialize(type:, value:, socure: false)
      @type = type
      @socure = socure
      @value = as_readable(value)
    end

    def bytes
      @bytes ||= readable? ? value&.read : nil
    end

    def fingerprint
      return nil unless readable?
      return @fingerprint if @fingerprint

      Digest::SHA256.urlsafe_base64digest(bytes)
    end

    def extra_attribute_key
      :"#{type}_image_fingerprint"
    end

    def upload_key
      :"#{type}_image"
    end

    def attempts_tracker_file_id_key
      :"document_#{type}_image_file_id"
    end

    def attempts_tracker_encryption_key
      :"document_#{type}_image_encryption_key"
    end

    private

    def as_readable(val)
      if val.respond_to?(:read)
        val
      elsif socure
        Idv::BinaryImage.new(val)
      elsif val.is_a? String
        Idv::DataUrlImage.new(val)
      end
    rescue Idv::DataUrlImage::InvalidUrlFormatError,
           Idv::BinaryImage::InvalidFormatError => error
      error
    end

    def readable?
      value.present? && !value.is_a?(Idv::DataUrlImage::InvalidUrlFormatError)
    end
  end
end
