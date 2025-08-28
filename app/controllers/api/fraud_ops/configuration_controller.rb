# frozen_string_literal: true

module Api
  module FraudOps
    class ConfigurationController < Attempts::ConfigurationController
      check_or_render_not_found -> { IdentityConfig.store.feature_fraudops_enabled }
    end
  end
end
