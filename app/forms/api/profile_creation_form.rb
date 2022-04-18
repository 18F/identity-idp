# rubocop:disable Style/RedundantAssignment, IdentityIdp/ErrorsAddLinter
module Api
  class ProfileCreationForm
    include ActiveModel::Model

    validate :valid_user_bundle
    validate :valid_user
    validate :valid_password

    attr_reader :user_password, :user_bundle, :user_bundle_headers, :user_bundle_payload
    attr_reader :user_session
    attr_reader :pii, :profile, :personal_key

    def initialize(user_password:, user_bundle:, user_session:)
      @user_password = user_password
      @user_bundle = user_bundle
      @user_session = user_session
      set_idv_session
    end

    def submit
      @form_valid = valid?

      create_profile
      cache_encrypted_pii
      generate_personal_key
      # complete_session
      # if idv_session.phone_confirmed?
      #   event = create_user_event_with_disavowal(:account_verified)
      #   UserAlerts::AlertUserAboutAccountVerified.call(
      #     user: current_user,
      #     date_time: event.created_at,
      #     sp_name: decorated_session.sp_name,
      #     disavowal_token: event.disavowal_token,
      #     )
      # end

      FormResponse.new(
        success: form_valid?,
        errors: errors,
        extra: extra_attributes,
      )
    end

    private

    def create_profile
      profile_maker = build_profile_maker
      profile = profile_maker.save_profile
      @pii = profile_maker.pii_attributes
      @profile = profile
    end

    def cache_encrypted_pii
      cacher = Pii::Cacher.new(current_user, session)
      cacher.save(user_password, profile)
    end

    def generate_personal_key
      @personal_key = profile.encrypt_recovery_pii(pii)
    end

    def complete_session
      complete_profile if phone_confirmed?
      create_gpo_entry if session[:address_verification_mechanism] == 'gpo'
    end

    def phone_confirmed?
      session[:vendor_phone_confirmation] == true && session[:user_phone_confirmation] == true
    end

    def complete_profile
      current_user.pending_profile&.activate
      move_pii_to_user_session
    end

    def create_gpo_entry
      move_pii_to_user_session
      self.pii = Pii::Attributes.new_from_json(user_session[:decrypted_pii]) if pii.is_a?(String)
      confirmation_maker = GpoConfirmationMaker.new(
        pii: pii, service_provider: service_provider,
        profile: profile
      )
      confirmation_maker.perform

      @gpo_otp = confirmation_maker.otp
    end

    def build_profile_maker
      Idv::ProfileMaker.new(
        applicant: user_bundle_payload,
        user: current_user,
        user_password: user_password,
      )
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = User.find_by(:user_uuid, user_bundle_headers['sub'])
    end

    def set_idv_session
      return if session.present?
      user_session[:idv] = {}
    end

    def session
      user_session.fetch(:idv, {})
    end

    # def move_pii_to_user_session
    #   return if session[:decrypted_pii].blank?
    #   user_session[:decrypted_pii] = session.delete(:decrypted_pii)
    # end

    def valid_user_bundle
      payload, headers = JWT.decode(
        user_bundle,
        public_key,
        true,
        algorithm: 'RS256',
      )
      @user_bundle_payload = payload
      @user_bundle_headers = headers
    rescue JWT::DecodeError => err
      errors.add(jwt: "decode error: #{err.message}")
    rescue JWT::ExpiredSignature => err
      errors.add(jwt: "expired signature: #{err.message}")
    end

    def valid_user
      return if current_user
      errors.add(user: 'user not found')
    end

    def valid_password
      return if current_user.valid_password?(password)
      errors.add(password: 'invalid password')
    end

    def form_valid?
      @form_valid
    end

    def extra_attributes
      @extra_attributes ||= {
        personal_key: personal_key,
        profile_pending: current_user.pending_profile?,
        user_uuid: current_user.uuid,
      }
    end

    def public_key
      Base64.strict_decode64(IdentityConfig.store.idv_public_key)
    end
  end
end
# rubocop:enable Style/RedundantAssignment, IdentityIdp/ErrorsAddLinter
