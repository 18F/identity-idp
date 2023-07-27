module Idv
  module InPerson
    module Public
      class AddressSearchController < ApplicationController
        include RenderConditionConcern

        check_or_render_not_found -> { enabled? }

        skip_forgery_protection

        def index
          addresses = geocoder.find_address_candidates(SingleLine: params[:address]).slice(0, 1)

          render json: addresses.to_json
        end

        def options
          head :ok
        end

        protected

        def geocoder
          ArcgisApi::Mock::Geocoder.new
        end

        def enabled?
          IdentityConfig.store.in_person_public_address_search_enabled
        end
      end
    end
  end
end
