module Idv
  module Ipp
    class UspsRequestEnrollForm
      include ActiveModel::Model
      include ActionView::Helpers::TranslationHelper

      def initialize(params, analytics: nil)
        @params = params
        @analytics = analytics
        @readable = {}
        @uuid_prefix = uuid_prefix
      end

      def submit
        form_response = validate_form

        client_response = nil

        client_response = post_images_to_client if form_response.success?

        determine_response(
          form_response: form_response,
          client_response: client_response,
        )
      end

      private

      attr_reader :params, :analytics, :form_response

      def throttled_else_increment
        return unless document_capture_session
        @throttled = throttle.throttled_else_increment?
      end

      def validate_form
        response = Idv::DocAuthFormResponse.new(
          success: valid?,
          errors: errors,
        )

        analytics.idv_doc_auth_submitted_image_upload_form(**response.to_h)

        response
      end

      def post_images_to_client
        response = nil
        response.extra.merge!(extra_attributes)

        update_analytics(response)

        response
      end

      def extra_attributes
        @extra_attributes ||= {
          user_id: user_uuid,
          pii_like_keypaths: [[:pii]],
        }
      end

      def determine_response(form_response:, client_response:, doc_pii_response:)
        # image validation failed
        return form_response unless form_response.success?

        # doc_pii validation failed
        return doc_pii_response if (doc_pii_response.present? && !doc_pii_response.success?)

        client_response
      end

      def track_event(event, attributes = {})
        if analytics.present?
          analytics.track_event(
            event,
            attributes,
          )
        end
      end

      def update_analytics(client_response)
        add_costs(client_response)
        update_funnel(client_response)
        analytics.idv_doc_auth_submitted_image_upload_vendor(
          **client_response.to_h.merge(
            client_image_metrics: image_metadata,
            async: false,
            flow_path: params[:flow_path],
          ),
        )
      end

      def user_id
        document_capture_session&.user&.id
      end

      def user_uuid
        document_capture_session&.user&.uuid
      end
    end
  end
end
