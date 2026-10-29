# frozen_string_literal: true

# Renders a 404 page for SAML endpoints that are no longer live, e.g. a
# decommissioned signing year such as /api/saml/auth2024. When the inbound
# SAMLRequest can be decoded we name the service provider so the user knows who
# to contact; otherwise we fall back to generic copy.
class SamlDecommissionedController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :verify_authenticity_token

  def show
    @service_provider = find_service_provider(params[:SAMLRequest])
    @friendly_name = @service_provider&.friendly_name.presence ||
                     @service_provider&.agency&.name.presence ||
                     'this service provider'
    # Only ever link to the URL we have on file for the SP. The inbound request
    # is unauthenticated, so any URL it carries is attacker-controlled and must
    # not be rendered as a link.
    @return_to_sp_url = @service_provider&.return_to_sp_url.presence

    render 'show', layout: false, status: :not_found, formats: :html
  end

  private

  # @return [ServiceProvider, nil]
  def find_service_provider(raw_request)
    issuer = decode_issuer(raw_request)
    return nil if issuer.blank?

    ServiceProvider.find_by(issuer: issuer)
  end

  # Extracts the issuer from a SAMLRequest without verifying its signature. This
  # is display-only: the value is used to look up a service provider by exact
  # match, never to make an authorization decision.
  # @return [String, nil]
  def decode_issuer(raw_request)
    return nil if raw_request.blank?

    SamlIdp::Request.from_deflated_request(raw_request).issuer
  rescue StandardError
    # Malformed input is expected here; the caller renders generic copy.
    nil
  end
end
