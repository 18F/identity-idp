module Idv
  class UserBundleTokenizer
    def initialize(user:, idv_session:)
      @user = user
      @idv_session = idv_session
    end

    def token
      JWT.encode(
        {
          # for now, load whatever pii is saved in the session
          pii: idv_session.applicant,
          metadata: metadata,
        },
        private_key,
        'RS256',
        sub: user.uuid,
      )
    end

    private

    attr_reader :user, :idv_session

    def private_key
      OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_private_key))
    end

    def metadata
      # populate with anything from the session we'll need later on
      data = {}

      data[:address_verification_mechanism] = idv_session.address_verification_mechanism
      data[:user_phone_confirmation] = idv_session.user_phone_confirmation
      data[:vendor_phone_confirmation] = idv_session.vendor_phone_confirmation
      data[:in_person_enrollment] = idv_session.pending_in_person_enrollment?

      data
    end
  end
end
