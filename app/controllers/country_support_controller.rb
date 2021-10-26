class CountrySupportController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :disable_caching

  def index
    expires_in 15.minutes, public: true

    render json: { countries: PhoneNumberCapabilities::INTERNATIONAL_CODES }
  end
end
