module Idv
  class PersonalKeyController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include SecureHeadersConcern
    include FraudReviewConcern
    include OptInHelper

    before_action :apply_secure_headers_override
    before_action :confirm_two_factor_authenticated
    before_action :confirm_step_allowed

    # Personal key is kind of a special case, since you're always meant to
    # look at it after your profile has been minted. We opt out of a few
    # standard before_actions and handle them in our own special way below.
    skip_before_action :confirm_idv_needed
    skip_before_action :confirm_personal_key_acknowledged_if_needed
    skip_before_action :confirm_no_pending_in_person_enrollment
    skip_before_action :handle_fraud

    def show
      analytics.idv_personal_key_visited(
        address_verification_method: idv_session.address_verification_mechanism,
        in_person_verification_pending: idv_session.profile&.in_person_verification_pending?,
        **opt_in_analytics_properties,
      )
      add_proofing_component

      finish_idv_session
    end

    def update
      analytics.idv_personal_key_submitted(
        address_verification_method: idv_session.address_verification_mechanism,
        deactivation_reason: idv_session.profile&.deactivation_reason,
        in_person_verification_pending: idv_session.profile&.in_person_verification_pending?,
        fraud_review_pending: fraud_review_pending?,
        fraud_rejection: fraud_rejection?,
      )

      idv_session.acknowledge_personal_key!

      redirect_to next_step
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :personal_key,
        controller: self,
        next_steps: [FlowPolicy::FINAL],
        preconditions: ->(idv_session:, user:) do
          return false unless idv_session.address_confirmed? || idv_session.phone_confirmed?

          return false unless user.active_or_pending_profile

          !idv_session.personal_key_acknowledged
        end,
        undo_step: ->(idv_session:, user:) {
          idv_session.personal_key_acknowledged = nil
        },
      )
    end

    private

    def next_step
      if in_person_enrollment?
        idv_in_person_ready_to_verify_url
      elsif fraud_check_failed?
        idv_please_call_url
      elsif session[:sp]
        sign_up_completed_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def add_proofing_component
      ProofingComponent.find_or_create_by(user: current_user).update(verified_at: Time.zone.now)
    end

    def finish_idv_session
      @code = personal_key
      @personal_key_generated_at = current_user.personal_key_generated_at

      idv_session.personal_key = @code

      irs_attempts_api_tracker.idv_personal_key_generated
    end

    def personal_key
      idv_session.personal_key || generate_personal_key
    end

    def profile
      return idv_session.profile if idv_session.profile
      current_user.active_or_pending_profile
    end

    def generate_personal_key
      cacher = Pii::Cacher.new(current_user, user_session)

      new_personal_key = nil

      Profile.transaction do
        current_user.profiles.each do |profile|
          pii = cacher.fetch(profile.id)
          next if pii.nil?

          new_personal_key = profile.encrypt_recovery_pii(pii, personal_key: new_personal_key)

          profile.save!
        end
      end

      new_personal_key
    end

    def in_person_enrollment?
      return false unless IdentityConfig.store.in_person_proofing_enabled
      current_user.pending_in_person_enrollment.present?
    end
  end
end
