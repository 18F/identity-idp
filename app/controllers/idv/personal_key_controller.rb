# frozen_string_literal: true

module Idv
  class PersonalKeyController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include SecureHeadersConcern
    include OptInHelper

    before_action :apply_secure_headers_override
    before_action :confirm_step_allowed

    # Personal key is kind of a special case, since you're always meant to
    # look at it after your profile has been minted. We opt out of a few
    # standard before_actions and handle them in our own special way below.
    skip_before_action :confirm_idv_needed
    skip_before_action :confirm_personal_key_acknowledged_if_needed
    skip_before_action :confirm_no_pending_profile

    def show
      analytics.idv_personal_key_visited(
        address_verification_method: idv_session.address_verification_mechanism,
        in_person_verification_pending: idv_session.profile&.in_person_verification_pending?,
        encrypted_profiles_missing: pii_is_missing?,
        **opt_in_analytics_properties,
      )

      if pii_is_missing?
        redirect_to_retrieve_pii
      else
        finish_idv_session
      end
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
          idv_session.phone_or_address_step_complete? &&
            user.active_or_pending_profile &&
            !idv_session.personal_key_acknowledged
        end,
        undo_step: ->(idv_session:, user:) {
          idv_session.invalidate_personal_key!
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
      elsif idv_session.address_verification_mechanism == 'gpo'
        idv_sp_follow_up_path
      else
        after_sign_in_path_for(current_user)
      end
    end

    def finish_idv_session
      @code = personal_key
      @personal_key_generated_at = current_user.personal_key_generated_at

      idv_session.personal_key = @code
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

    def pii_is_missing?
      user_session[:encrypted_profiles].blank?
    end

    def redirect_to_retrieve_pii
      user_session[:stored_location] = request.original_fullpath
      redirect_to fix_broken_personal_key_url
    end

    def step_indicator_step
      if gpo_address_verification?
        :secure_account
      elsif in_person_proofing?
        :go_to_the_post_office
      else
        :re_enter_password
      end
    end
    helper_method :step_indicator_step
  end
end
