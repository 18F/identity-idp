# This module defines an interface for storing when an issuer has forced re-authentication
# for an active session. A request to force re-authentication that does not result
# in the user needing to re-authenticate due to not being authenticated should be excluded.

module ForcedReauthenticationConcern
  def issuer_forced_reauthentication?(issuer:)
    session.dig(:forced_reauthentication_sps, issuer) == true
  end

  def set_issuer_forced_reauthentication(issuer:, is_forced_reauthentication:)
    if is_forced_reauthentication
      session[:forced_reauthentication_sps] ||= {}
      session[:forced_reauthentication_sps][issuer] = true
    elsif session[:forced_reauthentication_sps]
      session[:forced_reauthentication_sps].delete(issuer)
      session.delete(:forced_reauthentication_sps) if session[:forced_reauthentication_sps].blank?
    end
  end
end
