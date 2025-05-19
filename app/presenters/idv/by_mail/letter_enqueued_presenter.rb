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
          pii.address1,
          pii.address2.presence,
          "#{pii.city}, #{pii.state} #{pii.zipcode}",
        ].compact
      end

      def button_destination
        if sp
          return_to_sp_cancel_path(step: :verify_address, location: :come_back_later)
        else
          marketing_site_redirect_path
        end
      end

      def sp_name
        sp&.friendly_name
      end

      def show_sp_contact_instructions?
        sp_name.present?
      end

      private

      attr_accessor :idv_session, :user_session, :current_user

      def sp
        @sp ||= idv_session.service_provider
      end

      def pii
        @pii ||= pii_from_session_applicant || pii_from_gpo_pending_profile
      end

      def pii_from_session_applicant
        return nil if idv_session&.applicant.nil?
        Pii::Attributes.new_from_hash(idv_session.applicant)
      end

      def pii_from_gpo_pending_profile
        Pii::Cacher.new(current_user, user_session)
          .fetch(current_user&.gpo_verification_pending_profile&.id)
      end
    end
  end
end
