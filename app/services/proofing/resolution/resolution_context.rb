# frozen_string_literal: true

module Proofing
  module Resolution
    class ResolutionContext
      ## A container for resolution, pii, user_email, config store
      attr_reader :pii, :app_config_store
      attr_accessor :user_email

      # @param [Pii::Attributes] pii
      # @param [String] user_email
      def initialize(pii:, user_email: nil)
        @pii = pii
        @user_email = user_email
        @app_config_store = IdentityConfig.store
      end
    end
  end
end
