# frozen_string_literal: true

# This module defines an interface for storing when an issuer has forced re-authentication
# for an active session. A request to force re-authentication that does not result
# in the user needing to re-authenticate due to not being authenticated should be excluded.

module ForcedReauthenticationConcern
  def issuer_forced_reauthentication?(issuer:)
    session.dig(:forced_reauthentication_sps, issuer) != nil
  end

  def meets_sp_reauthentication_requirements?(issuer:)
    requested_at = session.dig(:forced_reauthentication_sps, issuer, :requested_at)
    reauthenticated_at = session.dig(:forced_reauthentication_sps, issuer, :reauthenticated_at)

    if requested_at
      reauthenticated_at.present? && reauthenticated_at > requested_at
    else
      true
    end
  end

  def set_issuer_forced_reauthentication_success(issuer:)
    if session.dig(:forced_reauthentication_sps, issuer, :requested_at)
      session[:forced_reauthentication_sps][issuer][:reauthenticated_at] = Time.zone.now
    end
  end

  def set_issuer_forced_reauthentication(issuer:, is_forced_reauthentication:)
    if is_forced_reauthentication
      session[:forced_reauthentication_sps] ||= {}
      session[:forced_reauthentication_sps][issuer] = { requested_at: Time.zone.now }
    elsif session[:forced_reauthentication_sps]
      session[:forced_reauthentication_sps].delete(issuer)
      session.delete(:forced_reauthentication_sps) if session[:forced_reauthentication_sps].blank?
    end
  end
end
