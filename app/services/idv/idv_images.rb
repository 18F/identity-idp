# frozen_string_literal: true

module Idv
  class IdvImages
    TYPES = %i[front back passport selfie].freeze

    # @returns [Array<Idv::Image>] Contains 0 to 1 Idv::Image per IdvImages::TYPES item
    attr_reader :images
    # @returns [Hash{Symbol => Hash}] errors are keyed by Idv::Image#type
    attr_accessor :errors

    def initialize(params, binary_image: false)
      @images = TYPES.map do |type|
        next unless params[type].present?

        Idv::IdvImage.new(type:, value: params[type], binary_image:)
      end.compact
      @errors = {}
    end

    def attempts_file_data
      images.each_with_object({}) do |image, obj|
        result = write_image(image.bytes)
        obj[image.attempts_tracker_file_id_key] = result.name
        obj[image.attempts_tracker_encryption_key] = result.encryption_key
      end
    end

    def write_with_data(image_storage_data:)
      image_storage_data.keys.each do |key|
        image = send(key)
        next unless image.present?

        encryption_key = Base64.strict_decode64(
          image_storage_data[key][image.attempts_tracker_encryption_key],
        )
        name = image_storage_data[key][image.attempts_tracker_file_id_key]

        write_image_with_data(image.bytes, encryption_key:, name:)
      end
    end

    def submittable_images
      images.each_with_object({}) do |image, obj|
        obj[image.upload_key] = image.bytes
      end
    end

    def passport_submittal
      @passport_submittal ||= images.any? { |image| image.type == :passport }
    end

    def needed_images_present?(liveness_checking_required)
      if liveness_checking_required && selfie.nil?
        @errors[:selfie] = { type: :blank }
      elsif !passport_submittal
        [:front, :back].each do |image|
          if send(image).nil?
            @errors[image] = { type: :blank }
          end
        end
      end

      errors
    end

    def front
      images.find { |image| image.type == :front }
    end

    def back
      images.find { |image| image.type == :back }
    end

    def selfie
      images.find { |image| image.type == :selfie }
    end

    private

    def write_image(image)
      encrypted_document_storage_writer.write(image:)
    end

    def write_image_with_data(image, encryption_key:, name:)
      encrypted_document_storage_writer.write_with_data(image:, encryption_key:, name:)
    end

    def encrypted_document_storage_writer
      @encrypted_document_storage_writer ||= EncryptedDocStorage::DocWriter.new(
        s3_enabled: doc_escrow_s3_storage_enabled?,
      )
    end

    def doc_escrow_s3_storage_enabled?
      IdentityConfig.store.doc_escrow_s3_storage_enabled
    end
  end
end
