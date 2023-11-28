module Idv
  module AvailabilityConcern
    extend ActiveSupport::Concern

    included do
      before_action :redirect_if_idv_unavailable
    end

    def redirect_if_idv_unavailable
      return if FeatureManagement.idv_available?

      redirect_to idv_unavailable_url
    end
  end
end
