module Idv
  module ByMail
    class LetterEnqueuedPresenter
      include ActionView::Helpers::TranslationHelper
      include Rails.application.routes.url_helpers

      def initialize(idv_session)
        @pii = idv_session.pii_from_doc ||
               idv_session.user_session.dig('idv/in_person', :pii_from_user) ||
               Pii::Cacher.new(idv_session.current_user, idv_session.user_session).
                 fetch(idv_session.current_user.gpo_verification_pending_profile.id)
        @sp = idv_session.service_provider
      end

      def address_lines
        [
          pii[:address1],
          pii[:address2],
          "#{pii[:city]}, #{pii[:state]} #{pii[:zipcode]}",
        ].compact
      end

      def button_text
        if sp
          t('idv.cancel.actions.exit', app_name: APP_NAME)
        else
          t('idv.buttons.continue_plain')
        end
      end

      def button_destination
        if sp
          return_to_sp_cancel_path(step: :get_a_letter, location: :come_back_later)
        else
          account_path
        end
      end

      def url_options
        {}
      end

      private

      attr_reader :pii, :sp
    end
  end
end
