module Idv
  module Steps
    class DocumentCaptureStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_id

      IMAGE_UPLOAD_PARAM_NAMES = %i[
        front_image back_image selfie_image
      ].freeze

      def call
        if request_should_use_stored_result?
          handle_stored_result
        else
          post_images_and_handle_result
        end
      end

      def extra_view_variables
        url_builder = ImageUploadPresignedUrlGenerator.new

        {
          front_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'front',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
          back_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'back',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
          selfie_image_upload_url: url_builder.presigned_image_upload_url(
            image_type: 'selfie',
            transaction_id: flow_session[:document_capture_session_uuid],
          ),
        }
      end

      private

      def post_images_and_handle_result
        response = post_images
        return handle_document_verification_failure(response) unless response.success?
        doc_pii_form_result = Idv::DocPiiForm.new(response.pii_from_doc).submit
        unless doc_pii_form_result.success?
          doc_auth_form_result = DocAuth::Response.new(
            success: false,
            errors: doc_pii_form_result.errors,
            extra: {
              pii_like_keypaths: [[:pii]],
            },
          )
          doc_auth_form_result = doc_auth_form_result.merge(response)
          return handle_document_verification_failure(doc_auth_form_result)
        end

        save_proofing_components
        document_capture_session.store_result_from_response(response)
        extract_pii_from_doc(response)
        response
      end

      def post_images
        return throttled_response if throttled_else_increment

        result = DocAuthRouter.client(
          vendor_discriminator: flow_session[:document_capture_session_uuid],
          warn_notifier: proc do |attrs|
            @flow.analytics.track_event(Analytics::DOC_AUTH_WARNING, attrs)
          end,
        ).post_images(
          front_image: front_image.read,
          back_image: back_image.read,
          selfie_image: selfie_image&.read,
          liveness_checking_enabled: liveness_checking_enabled?,
          image_source: DocAuth::ImageSources::UNKNOWN, # No-JS flow doesn't use Acuant SDK
        )
        # DP: should these cost recordings happen in the doc_auth_client?
        add_costs(result)
        result
      end

      def handle_document_verification_failure(response)
        mark_step_incomplete(:document_capture)
        notice = if liveness_checking_enabled?
                   { notice: I18n.t('errors.doc_auth.document_capture_info_with_selfie_html') }
                 else
                   { notice: I18n.t('errors.doc_auth.document_capture_info_html') }
                 end
        log_document_error(response)
        extra = response.to_h.merge(notice)
        failure(response.first_error_message, extra)
      end

      def log_document_error(get_results_response)
        return unless get_results_response.is_a?(DocAuth::Acuant::Responses::GetResultsResponse)

        Funnel::DocAuth::LogDocumentError.call(
          user_id,
          get_results_response&.result_code&.name.to_s,
        )
      end

      def handle_stored_result
        if stored_result.success?
          extract_pii_from_doc(stored_result)
        else
          extra = { stored_result_present: stored_result.present? }
          failure(I18n.t('doc_auth.errors.general.network_error'), extra)
        end
      end

      def stored_result
        return @stored_result if defined?(@stored_result)
        @stored_result = document_capture_session&.load_result ||
                         document_capture_session&.load_doc_auth_async_result
      end

      def request_should_use_stored_result?
        return false if stored_result.blank?
        IMAGE_UPLOAD_PARAM_NAMES.each do |param_name|
          return false if flow_params[param_name].present?
        end
        true
      end

      def front_image
        flow_params[:front_image]
      end

      def back_image
        flow_params[:back_image]
      end

      def selfie_image
        return nil unless liveness_checking_enabled?
        flow_params[:selfie_image]
      end

      def form_submit
        return FormResponse.new(success: true) if request_should_use_stored_result?

        Idv::DocumentCaptureForm.
          new(liveness_checking_enabled: liveness_checking_enabled?).
          submit(permit(IMAGE_UPLOAD_PARAM_NAMES))
      end
    end
  end
end
