class CountrySupportController < ApplicationController
  def index
    render json: { countries: PhoneNumberCapabilities::INTERNATIONAL_CODES }
  end
end
