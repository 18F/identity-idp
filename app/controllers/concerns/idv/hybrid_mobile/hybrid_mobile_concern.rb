module Idv
  module HybridMobile
    module HybridMobileConcern
      extend ActiveSupport::Concern

      included do
        before_action :render_404_if_hybrid_mobile_controllers_disabled
      end

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end
    end
  end
end
