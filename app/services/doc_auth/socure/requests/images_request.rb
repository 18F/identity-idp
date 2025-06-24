# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class ImagesRequest < DocAuth::Socure::Request
        MAX_IMAGE_SIZE = 5 * 1024 * 1024 # 5 MB

        def initialize(reference_id:)
          @reference_id = reference_id
        end

        private

        attr_reader :reference_id

        def content_type
          'application/zip'
        end

        def handle_http_response(http_response)
          image_files = {}
          Zip::File.open_buffer(http_response.body).entries.each do |entry|
            raise 'File too large when extracted' if entry.size > MAX_IMAGE_SIZE
            raise 'Too many files' if image_files.keys.count > 3
            param_name = entry_name_to_type[entry.name]
            next if param_name.blank?

            image_files[param_name] = entry.get_input_stream.read
          end

          Idv::IdvImages.new(image_files, binary_image: true)
        end

        def entry_name_to_type
          {
            'documentbackDoc_Back_1_blob.jpg' => :back,
            'documentfrontDoc_Front_1_blob.jpg' => :front,
            'Doc_Selfie_1_blob.jpg' => :selfie,
          }
        end

        def method
          :get
        end

        def endpoint
          @endpoint ||= URI.join(
            IdentityConfig.store.socure_docv_images_request_endpoint,
            reference_id,
          ).to_s
        end

        def metric_name
          'socure_images_requested'
        end
      end
    end
  end
end
