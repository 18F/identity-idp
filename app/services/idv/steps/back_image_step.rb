module Idv
  module Steps
    class BackImageStep < DocAuthBaseStep
      def call
        good, data = assure_id.post_back_image(image.read)
        return failure(data) unless good

        failure_data, data = verify_back_image
        return failure_data if failure_data

        extract_pii_from_doc_and_perform_resolution(data)
      end

      private

      def form_submit
        Idv::ImageUploadForm.new(current_user).submit(permit(:image))
      end

      def extract_pii_from_doc_and_perform_resolution(data)
        pii_from_doc = Idv::Utils::PiiFromDoc.new(data).
                       call(flow_session[:ssn], current_user.phone_configurations.first.phone)
        result = perform_resolution(pii_from_doc)
        if result.success?
          step_successful(pii_from_doc)
        else
          failure(I18n.t('idv.failure.sessions.heading'))
        end
      end

      def step_successful(pii_from_doc)
        mark_step_complete(:doc_failed) # skip doc failed
        save_legacy_state(pii_from_doc)
      end

      def save_legacy_state(pii_from_doc)
        skip_legacy_steps
        idv_session['params'] = pii_from_doc
        idv_session['applicant'] = pii_from_doc
        idv_session['applicant']['uuid'] = current_user.uuid
      end

      def skip_legacy_steps
        idv_session['profile_confirmation'] = true
        idv_session['vendor_phone_confirmation'] = true
        idv_session['user_phone_confirmation'] = true
        idv_session['address_verification_mechanism'] = 'phone'
        idv_session['resolution_successful'] = 'phone'
      end

      def perform_resolution(pii_from_doc)
        idv_result = Idv::Agent.new(pii_from_doc).proof(:resolution)
        FormResponse.new(
          success: idv_result[:success], errors: idv_result[:errors]
        )
      end

      def verify_back_image
        back_image_verified, data = assure_id.results
        return failure(data) unless back_image_verified

        return [nil, data] if data['Result'] == 1

        failure_alerts(data)
      end

      def failure_alerts(data)
        failure(data['Alerts'].
          reject { |res| res['Result'] == 2 }.
          map { |act| act['Actions'] })
      end
    end
  end
end
