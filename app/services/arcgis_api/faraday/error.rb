module ArcgisApi::Faraday
  # Raised when the ArcGIS API returns an error that
  # uses a 2xx HTTP status code.
  #
  # This extends from Faraday::Error to preserve LSP
  # while allowing for distinct handling.
  class Error < Faraday::Error
  end
end
