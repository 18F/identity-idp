module Api
  class UserBundleError < StandardError; end

  class UserBundleDecorator
    # Note, does not rescue JWT errors - responsibility of the user
    def initialize(user_bundle:, public_key:)
      payload, headers = JWT.decode(
        user_bundle,
        public_key,
        true,
        algorithm: 'RS256',
      )
      @jwt_payload = payload
      @jwt_headers = headers

      raise UserBundleError.new('pii is missing') unless jwt_payload['pii']
      raise UserBundleError.new('metadata is missing') unless jwt_payload['metadata']
    end

    def gpo_address_verification?
      metadata[:address_verification_mechanism] == 'gpo'
    end

    def pii
      HashWithIndifferentAccess.new(jwt_payload['pii'])
    end

    def user
      return @user if defined?(@user)
      @user = User.find_by(uuid: jwt_headers['sub'])
    end

    def user_phone_confirmation?
      metadata[:user_phone_confirmation] == true
    end

    def vendor_phone_confirmation?
      metadata[:vendor_phone_confirmation] == true
    end

    private

    attr_reader :jwt_payload, :jwt_headers

    def metadata
      HashWithIndifferentAccess.new(jwt_payload['metadata'])
    end
  end
end
