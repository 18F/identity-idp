module Api
  class ProfileCreationForm
    include ActiveModel::Model

    validate :valid_jwt
    validate :valid_user
    validate :valid_password

    attr_reader :password, :user_bundle, :user_session, :service_provider, :profile, :gpo_code

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

      response = FormResponse.new(
        success: form_valid?,
        errors: errors,
        extra: extra_attributes,
      )
      [response, personal_key]
    end

    private

    attr_reader :jwt

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
      create_gpo_entry if user_bundle.gpo_address_verification?
    end

    def phone_confirmed?
      user_bundle.vendor_phone_confirmation? && user_bundle.user_phone_confirmation?
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
      confirmation_maker = GpoConfirmationMaker.new(
        pii: Pii::Cacher.new(user, user_session).fetch,
        service_provider: service_provider,
        profile: profile,
      )
      confirmation_maker.perform
      @gpo_code = confirmation_maker.otp if FeatureManagement.reveal_gpo_code?
    end

    def build_profile_maker
      Idv::ProfileMaker.new(
        applicant: user_bundle.pii,
        user: user,
        user_password: password,
      )
    end

    def user
      user_bundle&.user
    end

    def set_idv_session
      return if session.present?
      user_session[:idv] = {}
    end

    def session
      user_session.fetch(:idv, {})
    end

    def valid_jwt
      @user_bundle = Api::UserBundleDecorator.new(user_bundle: jwt, public_key: public_key)
    rescue JWT::DecodeError
      errors.add(:jwt, I18n.t('idv.failure.exceptions.internal_error'), type: :decode_error)
    rescue ::Api::UserBundleError
      errors.add(:jwt, I18n.t('idv.failure.exceptions.internal_error'), type: :user_bundle_error)
    end

    def valid_user
      return if user
      errors.add(:user, I18n.t('devise.failure.unauthenticated'), type: :invalid_user)
    end

    def valid_password
      return if user&.valid_password?(password)
      errors.add(:password, I18n.t('idv.errors.incorrect_password'), type: :invalid_password)
    end

    def form_valid?
      @form_valid
    end

    def extra_attributes
      if user.present?
        @extra_attributes ||= {
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
      key = OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_public_key))

      if Identity::Hostdata.in_datacenter?
        env = Identity::Hostdata.env
        prod_env = env == 'prod' || env == 'staging' || env == 'dm'
        raise 'key size too small' if prod_env && key.n.num_bits < 2048
      end

      key
    end
  end
end
