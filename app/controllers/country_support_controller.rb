class CountrySupportController < ApplicationController
  skip_before_action :disable_caching

  def index
    expires_in 15.minutes, public: true

    render json: { countries: PhoneNumberCapabilities::INTERNATIONAL_CODES }
  end
end
