# frozen_string_literal: true

module Idv
  class FlowPolicy
    attr_reader :idv_session, :user

    FINAL = :final
    STEPS =
      {
        root: Idv::StepInfo.new(
          key: :root,
          controller: AccountsController,
          next_steps: [:welcome, :request_letter],
          preconditions: ->(idv_session:, user:) { true },
          undo_step: ->(idv_session:, user:) { true },
        ),
        welcome: Idv::WelcomeController.step_info,
        agreement: Idv::AgreementController.step_info,
        how_to_verify: Idv::HowToVerifyController.step_info,
        hybrid_handoff: Idv::HybridHandoffController.step_info,
        link_sent: Idv::LinkSentController.step_info,
        document_capture: Idv::DocumentCaptureController.step_info,
        socure_document_capture: Idv::Socure::DocumentCaptureController.step_info,
        socure_errors: Idv::Socure::ErrorsController.step_info,
        ipp_state_id: Idv::InPerson::StateIdController.step_info,
        ipp_address: Idv::InPerson::AddressController.step_info,
        ssn: Idv::SsnController.step_info,
        ipp_ssn: Idv::InPerson::SsnController.step_info,
        verify_info: Idv::VerifyInfoController.step_info,
        ipp_verify_info: Idv::InPerson::VerifyInfoController.step_info,
        address: Idv::AddressController.step_info,
        phone: Idv::PhoneController.step_info,
        phone_errors: Idv::PhoneErrorsController.step_info,
        otp_verification: Idv::OtpVerificationController.step_info,
        request_letter: Idv::ByMail::RequestLetterController.step_info,
        enter_password: Idv::EnterPasswordController.step_info,
        personal_key: Idv::PersonalKeyController.step_info,
      }.freeze

    def initialize(idv_session:, user:)
      @idv_session = idv_session
      @user = user
    end

    def controller_allowed?(controller:)
      controller_name = controller < ApplicationController ?
                          StepInfo.full_controller_name(controller) : controller
      key = controller_to_key(controller: controller_name)
      step_allowed?(key: key)
    end

    def info_for_latest_step
      steps[latest_step]
    end

    def undo_future_steps_from_controller!(controller:)
      controller_name = controller < ApplicationController ?
                          StepInfo.full_controller_name(controller) : controller
      key = controller_to_key(controller: controller_name)
      undo_future_steps!(key: key)
    end

    private

    def latest_step(current_step: :root)
      return nil if steps[current_step]&.next_steps.blank?
      return current_step if steps[current_step].next_steps == [FINAL]

      steps[current_step].next_steps.each do |key|
        if step_allowed?(key: key)
          return latest_step(current_step: key)
        end
      end
      current_step
    end

    def steps
      STEPS
    end

    def step_allowed?(key:)
      steps[key].preconditions.call(idv_session: idv_session, user: user)
    end

    def undo_steps_from!(key:)
      return if key == FINAL

      steps[key].next_steps.each do |next_step|
        undo_steps_from!(key: next_step)
      end

      steps[key].undo_step.call(idv_session: idv_session, user: user)
    end

    def undo_future_steps!(key:)
      steps[key].next_steps.each do |next_step|
        undo_steps_from!(key: next_step)
      end
    end

    def controller_to_key(controller:)
      steps.keys.each do |key|
        return key if steps[key].controller == controller
      end
    end
  end
end
