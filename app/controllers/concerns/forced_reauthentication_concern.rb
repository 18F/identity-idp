# This module defines an interface for storing when an issuer has forced re-authentication
# for an active session. A request to force re-authentication that does not result
# in the user needing to re-authenticate due to not being authenticated should be excluded.

module ForcedReauthenticationConcern
  def issuer_forced_reauthentication?(issuer:)
    session.dig(:forced_reauthentication_sps, issuer) == true
  end

  def set_issuer_forced_reauthentication(issuer:, is_forced_reauthentication:)
    session[:forced_reauthentication_sps] ||= {}
    session[:forced_reauthentication_sps][issuer] = is_forced_reauthentication
  end
end
