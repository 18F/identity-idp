# frozen_string_literal: true

# After each sign in, update unique_session_id.
# This is only triggered when the user is explicitly set (with set_user)
# and on authentication. Retrieving the user from session (:fetch) does
# not trigger it.
Warden::Manager.after_set_user(except: :fetch) do |record, warden, options|
  if warden.authenticated?(options[:scope])
    unique_session_id = Devise.friendly_token
    warden.session(options[:scope])['unique_session_id'] = unique_session_id
    record.update!(unique_session_id: unique_session_id)
  end
end

# Each time a record is fetched from session we check if a new session from another
# browser was opened for the record or not, based on a unique session identifier.
# If so, the old account is logged out and redirected to the sign in page on the next request.
Warden::Manager.after_set_user(only: :fetch) do |record, warden, options|
  scope = options[:scope]
  current_session_id = warden.session(scope)['unique_session_id']

  if warden.authenticated?(scope) && options[:store] != false
    if record.unique_session_id != current_session_id
      service_provider = warden.raw_session.dig('sp')
      analytics = Analytics.new(
        user: record,
        request: warden.request,
        session: warden.raw_session,
        sp: warden.raw_session.dig('sp', 'issuer'),
      )
      analytics.concurrent_session_logout
      warden.raw_session.clear
      warden.logout(scope)
      warden.raw_session['sp'] = service_provider
      throw :warden, scope: scope, message: :session_limited
    end
  end
end
