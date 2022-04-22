module Api
  class ProfileCreationForm
    include ActiveModel::Model

    validate :valid_jwt
    validate :valid_user
    validate :valid_password

    attr_reader :password, :jwt, :jwt_headers, :jwt_payload
    attr_reader :user_session, :service_provider
    attr_reader :profile, :gpo_otp

    def initialize(password:, jwt:, user_session:, service_provider: nil)
      @password = password
      @jwt = jwt
      @user_session = user_session
      @service_provider = service_provider
      set_idv_session
    end

    def submit
      @form_valid = valid?

      if form_valid?
        create_profile
        cache_encrypted_pii
        complete_session
      end

      FormResponse.new(
        success: form_valid?,
        errors: errors.to_hash,
        extra: extra_attributes,
      )
    end

    private

    def create_profile
      profile_maker = build_profile_maker
      profile = profile_maker.save_profile
      @profile = profile
      session[:pii] = profile_maker.pii_attributes
      session[:profile_id] = profile.id
      session[:personal_key] = profile.personal_key
    end

    def cache_encrypted_pii
      cacher = Pii::Cacher.new(user, session)
      cacher.save(password, profile)
    end

    def complete_session
      complete_profile if phone_confirmed?
      create_gpo_entry if session[:address_verification_mechanism] == 'gpo'
    end

    def phone_confirmed?
      session[:vendor_phone_confirmation] == true && session[:user_phone_confirmation] == true
    end

    def complete_profile
      user.pending_profile&.activate
      move_pii_to_user_session
    end

    def move_pii_to_user_session
      return if session[:decrypted_pii].blank?
      user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    end

    def create_gpo_entry
      move_pii_to_user_session
      if session[:pii].is_a?(String)
        session[:pii] = Pii::Attributes.new_from_json(user_session[:decrypted_pii])
      end
      confirmation_maker = GpoConfirmationMaker.new(
        pii: session[:pii],
        service_provider: service_provider,
        profile: profile
      )
      confirmation_maker.perform

      @gpo_otp = confirmation_maker.otp
    end

    def build_profile_maker
      Idv::ProfileMaker.new(
        applicant: jwt_payload,
        user: user,
        user_password: password,
      )
    end

    def user
      return nil unless jwt_headers
      return @user if defined?(@user)
      @user = User.find_by(uuid: jwt_headers['sub'])
    end

    def set_idv_session
      return if session.present?
      user_session[:idv] = {}
    end

    def session
      user_session.fetch(:idv, {})
    end

    def valid_jwt
      payload, headers = JWT.decode(
        jwt,
        public_key,
        true,
        algorithm: 'RS256',
      )
      @jwt_payload = payload
      @jwt_headers = headers
    rescue JWT::DecodeError => err
      errors.add(:jwt, "decode error: #{err.message}", type: :invalid)
    rescue JWT::ExpiredSignature => err
      errors.add(:jwt, "expired signature: #{err.message}", type: :invalid)
    end

    def valid_user
      return if user
      errors.add(:user, 'user not found', type: :invalid)
    end

    def valid_password
      return if user&.valid_password?(password)
      errors.add(:password, 'invalid password', type: :invalid)
    end

    def form_valid?
      @form_valid
    end

    def extra_attributes
      if user.present?
        @extra_attributes ||= {
          personal_key: personal_key,
          profile_pending: user.pending_profile?,
          user_uuid: user.uuid,
        }
      else
        @extra_attributes = {}
      end
    end

    def personal_key
      @personal_key ||= profile&.personal_key || profile&.encrypt_recovery_pii(pii)
    end

    def public_key
      OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_public_key))
    end
  end
end
