# frozen_string_literal: true

module Idv
  module ByMail
    class LetterRequestedEmailPresenter
      include ActionView::Helpers::TranslationHelper
      include Rails.application.routes.url_helpers

      attr_reader :current_user, :service_provider, :url_options
      def initialize(current_user:, url_options:)
        @current_user = current_user
        @url_options = url_options
        @service_provider = current_user.pending_profile&.initiating_service_provider
      end

      def sp_name
        service_provider&.friendly_name
      end

      def show_sp_contact_instructions?
        sp_name.present?
      end

      def show_cta?
        sign_in_url.present?
      end

      def sign_in_url
        if service_provider.present?
          service_provider_homepage_url
        else
          root_url
        end
      end

      private

      def service_provider_homepage_url
        sp_return_url_resolver.homepage_url if service_provider
      end

      def sp_return_url_resolver
        SpReturnUrlResolver.new(service_provider:)
      end
    end
  end
end
