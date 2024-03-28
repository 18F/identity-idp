module Idv
  module ByMail
    class LetterEnqueuedPresenter
      include ActionView::Helpers::TranslationHelper
      include Rails.application.routes.url_helpers

      def initialize(pii, decorated_sp_session)
        @pii = pii
        @decorated_sp_session = decorated_sp_session
      end

      def address_lines
        [
          pii[:address1],
          pii[:address2],
          "#{pii[:city]}, #{pii[:state]} #{pii[:zipcode]}",
        ].compact
      end

      def button_text
        if decorated_sp_session.sp_name.present?
          t('idv.cancel.actions.exit', app_name: APP_NAME)
        else
          t('idv.buttons.continue_plain')
        end
      end

      def button_destination
        if decorated_sp_session.sp_name.present?
          return_to_sp_cancel_path(step: :get_a_letter, location: :come_back_later)
        else
          account_path
        end
      end

      def url_options
        {}
      end

      private

      attr_reader :pii, :decorated_sp_session
    end
  end
end
