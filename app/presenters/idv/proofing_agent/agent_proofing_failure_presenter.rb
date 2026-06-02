# frozen_string_literal: true

module Idv
  module ProofingAgent
    class AgentProofingFailurePresenter
      include Rails.application.routes.url_helpers

      attr_reader :visited_at_string, :url_options

      def initialize(visited_at:, url_options:)
        @visited_at_string = visited_at
        @url_options = url_options
      end

      def help_center_url
        MarketingSite.help_url
      end

      def contact_us_url
        MarketingSite.contact_url
      end

      def change_password_url
        edit_user_password_url
      end

      def visited_at
        if @visited_at_string.is_a?(String)
          Time.zone.parse(@visited_at_string)
        else
          @visited_at_string
        end
      end
    end
  end
end
