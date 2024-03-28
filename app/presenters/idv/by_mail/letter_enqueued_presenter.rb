# frozen_string_literal: true

module Idv
  module ByMail
    class LetterEnqueuedPresenter
      include ActionView::Helpers::TranslationHelper
      include Rails.application.routes.url_helpers

      attr_reader :url_options

      def initialize(idv_session:, current_user:, user_session:, url_options:)
        @idv_session = idv_session
        @current_user = current_user
        @user_session = user_session
        @url_options = url_options
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

      private

      attr_accessor :idv_session, :user_session, :current_user

      def sp
        @sp ||= idv_session.service_provider
      end

      def pii
        @pii ||= pii_from_idv_session ||
                 pii_from_user_session ||
                 pii_from_gpo_pending_profile
      end

      def pii_from_idv_session
        idv_session.pii_from_doc
      end

      def pii_from_user_session
        idv_session.pii_from_user_in_flow_session
      end

      def pii_from_gpo_pending_profile
        Pii::Cacher.new(current_user, user_session).
          fetch(current_user&.gpo_verification_pending_profile&.id)
      end
    end
  end
end
