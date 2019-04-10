module Idv
  module Steps
    class UploadStep < DocAuthBaseStep
      def call
        have_mobile = mobile?
        if params[:type] == 'desktop'
          have_mobile ? mobile_to_desktop : desktop
        else
          have_mobile ? mobile : mark_step_complete(:email_sent)
        end
      end

      private

      def mobile?
        client = DeviceDetector.new(request.user_agent)
        client.device_type != 'desktop'
      end

      def identity
        current_user&.identities&.order('created_at DESC')&.first&.decorate
      end

      def link
        identity&.return_to_sp_url || root_url
      end

      def application
        identity&.friendly_name || 'login.gov'
      end

      def mobile_to_desktop
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        UserMailer.doc_auth_desktop_link_to_sp(current_user.email, application, link).deliver_later
      end

      def desktop
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        mark_step_complete(:email_sent)
        mark_step_complete(:mobile_front_image)
        mark_step_complete(:mobile_back_image)
      end

      def mobile
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        mark_step_complete(:email_sent)
        mark_step_complete(:front_image)
        mark_step_complete(:back_image)
      end
    end
  end
end
