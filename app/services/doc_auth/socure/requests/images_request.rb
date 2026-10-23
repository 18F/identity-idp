# frozen_string_literal: true

module DocAuth
  module Socure
    module Requests
      class ImagesRequest < DocAuth::Socure::Request
        MAX_IMAGE_SIZE = 5 * 1024 * 1024 # 5 MB

        def initialize(reference_id:, passport_book:, user:)
          @reference_id = reference_id
          @passport_book = passport_book
          @user = user
        end

        def fetch
          result = super
        ensure
          log_images_requested(result)
        end

        private

        attr_reader :reference_id, :user

        def send_http_request
          @http_response = super
        end

        def log_images_requested(result)
          analytics.idv_socure_images_requested(
            http_status: @http_response&.status,
            user_id: user.uuid,
            reference_id:,
            image_types_present: image_types_present(result),
            passport_book: !!@passport_book,
          )
        rescue StandardError => e
          NewRelic::Agent.notice_error(e)
        end

        def image_types_present(result)
          result.is_a?(Idv::IdvImages) ? result.images.map(&:type) : []
        end

        def analytics
          Analytics.new(user:, request: nil, session: {}, sp: nil)
        end

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
            'documentfrontDoc_Front_1_blob.jpg' => @passport_book ? :passport : :front,
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
