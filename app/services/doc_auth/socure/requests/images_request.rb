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

        def body
          {}
        end

        def content_type
          'application/zip'
        end

        def handle_http_response(http_response)
          zip_io = StringIO.new(http_response.body)

          image_files = {}
          # Open the zip stream
          Zip::InputStream.open(zip_io) do |io|
            # Iterate through entries
            # TODO do we need to protect against possible zip bombs here?
            while (entry = io.get_next_entry) && image_files.keys.count < 3
              raise 'File too large when extracted' if entry.size > MAX_IMAGE_SIZE
              param_name = entry_name_to_type[entry.name]
              next if param_name.blank?

              image_files[param_name] = io.read
            end
          end

          Idv::IdvImages.new(image_files, socure: true)
        end

        def entry_name_to_type
          {
            'documentfrontDoc_Back_1_blob.jpg' => :back,
            'documentfrontDoc_Front_1_blob.jpg' => :front,
            'Doc_Selfie_1_blob.jpg' => :selfie,
          }
        end

        def method
          :post
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
