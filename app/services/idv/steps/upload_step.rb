module Idv
  module Steps
    class UploadStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_id

      def self.analytics_visited_event
        :idv_doc_auth_upload_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_upload_submitted
      end

      def call
        @flow.irs_attempts_api_tracker.idv_document_upload_method_selected(
          upload_method: params[:type],
        )

        # See the simple_form_for in
        # app/views/idv/doc_auth/upload.html.erb
        if params[:type] == 'desktop'
          handle_desktop_selection
        else
          handle_mobile_selection
        end
      end

      private

      def handle_desktop_selection
        if mobile_device?
          send_user_to_email_sent_step
        else
          bypass_send_link_steps
        end
      end

      def handle_mobile_selection
        if mobile_device?
          bypass_send_link_steps
        else
          send_user_to_send_link_step
        end
      end

      def identity
        current_user&.identities&.order('created_at DESC')&.first
      end

      def link
        identity&.return_to_sp_url || root_url
      end

      def application
        identity&.friendly_name || APP_NAME
      end

      def send_user_to_email_sent_step
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        UserMailer.with(
          user: current_user, email_address: current_user.confirmed_email_addresses.first,
        ).doc_auth_desktop_link_to_sp(application, link).deliver_now_or_later
        form_response(destination: :email_sent)
      end

      def send_user_to_send_link_step
        mark_step_complete(:email_sent)
        form_response(destination: :send_link)
      end

      def bypass_send_link_steps
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        mark_step_complete(:email_sent)
        form_response(destination: :document_capture)
      end

      def mobile_device?
        # See app/javascript/packs/document-capture-welcome.js
        # And app/services/idv/steps/agreement_step.rb
        !!flow_session[:skip_upload_step]
      end

      def form_response(destination:)
        FormResponse.new(
          success: true,
          errors: {},
          extra: {
            destination: destination,
            skip_upload_step: mobile_device?,
          },
        )
      end
    end
  end
end
