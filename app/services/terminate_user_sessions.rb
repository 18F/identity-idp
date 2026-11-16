# frozen_string_literal: true

# Ends a person's server-side sessions when their password changes or their account is
# suspended. Devise's salt check already keeps a stale browser from finding its signed-in user
# once the password hash changes, but the session record itself lives on in Redis until its idle
# timeout, and it is read out of band: the OpenID Connect user-information endpoint (and the
# document image endpoint) resolve an access token to the session recorded on the person's
# identity row and serve attributes from the PII cache held in that record for as long as it
# exists, and the keep-alive endpoint renews it on request. Deleting the records closes that path;
# clearing the identity rows' access tokens and session pointers leaves nothing that resolves to
# them.
#
# Only sessions a sign-in to a service provider has recorded on an identity row can be found this
# way. A session that never reached a service provider holds nothing an out-of-band reader can
# resolve, and the salt check ends it for the browser.
class TerminateUserSessions
  # @param user [User]
  # @param except_session_id [String, nil] the Rack session id to keep, the session in which the
  #   person is changing their own password; nil ends every recorded session
  def initialize(user:, except_session_id: nil)
    @user = user
    @except_session_id = except_session_id
  end

  def call
    identities = user.identities.where.not(rails_session_id: nil)
    identities = identities.where.not(rails_session_id: except_session_id) if except_session_id

    identities.pluck(:rails_session_id).uniq.each do |session_id|
      OutOfBandSessionAccessor.new(session_id).destroy
    end
    # A column-only reset; the identity rows carry no validation that applies to these two columns.
    identities.update_all(access_token: nil, rails_session_id: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  attr_reader :user, :except_session_id
end
