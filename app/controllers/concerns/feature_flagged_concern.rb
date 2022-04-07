module FeatureFlaggedConcern
  extend ActiveSupport::Concern

  module ClassMethods
    def feature_flagged(config_key, **kwargs)
      before_action(**kwargs) { render_not_found unless IdentityConfig.store.send(config_key) }
    end
  end
end
