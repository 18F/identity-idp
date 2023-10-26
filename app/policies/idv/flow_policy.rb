module Idv
  class FlowPolicy
    attr_reader :idv_session, :user

    def initialize(idv_session:, user:)
      @idv_session = idv_session
      @user = user
    end

    def controller_allowed?(controller:)
      controller_name = controller.ancestors.include?(ApplicationController) ?
                          controller.controller_name : controller
      step = controller_to_step(controller: controller_name)
      step_allowed?(step: step)
    end

    def info_for_latest_step
      steps[latest_step]
    end

    def latest_step(current_step: :root)
      return nil if steps[current_step]&.next_steps.blank?
      return current_step if steps[current_step].next_steps == [:success]

      steps[current_step].next_steps.each do |step|
        if step_allowed?(step: step)
          return latest_step(current_step: step)
        end
      end
      current_step
    end

    private

    def steps
      {
        root: Idv::StepInfo.new(
          key: :root,
          controller: AccountsController.controller_name,
          next_steps: [:welcome],
          preconditions: ->(idv_session:, user:) { true },
        ),
        welcome: Idv::WelcomeController.navigation_step,
        agreement: Idv::AgreementController.navigation_step,
        phone_question: Idv::PhoneQuestionController.navigation_step,
        hybrid_handoff: Idv::HybridHandoffController.navigation_step,
        link_sent: Idv::LinkSentController.navigation_step,
        document_capture: Idv::DocumentCaptureController.navigation_step,
      }
    end

    def step_allowed?(step:)
      steps[step].preconditions.call(idv_session: idv_session, user: user)
    end

    def controller_to_step(controller:)
      steps.keys.each do |key|
        return key if steps[key].controller == controller
      end
    end
  end
end
