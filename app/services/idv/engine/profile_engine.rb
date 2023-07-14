module Idv::Engine
  # An implementation of Idv::Engine that uses the Profile model and IdvSession as its backing
  # data store.
  class ProfileEngine < Base
    attr_reader :idv_session, :user

    def initialize(user:, idv_session: nil)
      raise 'user is required' unless user
      @user = user
      @idv_session = idv_session
    end

    on :auth_password_reset do
    end

    on :idv_gpo_letter_requested do
      update_idv_session(
        address_verification_mechanism: :gpo,
      )
    end

    on :idv_ssn_entered_by_user do |params|
      update_idv_session_pii_from_doc(
        ssn: params.ssn,
      )
    end

    on :idv_threatmetrix_check_completed do |params|
      update_idv_session(
        threatmetrix_review_status: params.threatmetrix_review_status,
      )

      update_proofing_components(
        threatmetrix: FeatureManagement.proofing_device_profiling_collecting_enabled?,
        threatmetrix_review_status: params.threatmetrix_review_status,
      )
    end

    protected

    def assert_no_active_profile
      raise 'User has an active profile' if user.active_profile
    end

    def assert_idv_session_available
      raise 'idv_session is not available' unless idv_session
    end

    def build_verification
      Verification.new(
        valid: !!user.active_profile,
      )
    end

    def update_idv_session(fields)
      assert_idv_session_available
      assert_no_active_profile

      fields.each_pair do |key, value|
        idv_session[key] = value
      end
    end

    def update_idv_session_pii_from_doc(fields)
      assert_idv_session_available
      assert_no_active_profile

      idv_session[:pii_from_doc] = (idv_session[:pii_from_doc] || {}).merge(fields)
    end

    def update_proofing_components(fields)
      ProofingComponent.
        create_or_find_by(user_id: user.id).
        update(fields)
    end
  end
end
