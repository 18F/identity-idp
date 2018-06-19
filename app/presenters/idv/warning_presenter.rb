module Idv
  class WarningPresenter < FailurePresenter
    attr_reader :reason, :remaining_attempts, :step_name, :view_context

    delegate :idv_phone_path,
             :idv_session_path,
             :link_to,
             :t,
             to: :view_context

    def initialize(reason:, remaining_attempts:, step_name:, view_context:)
      super(:warning)
      @reason = reason
      @remaining_attempts = remaining_attempts
      @step_name = step_name
      @view_context = view_context
    end

    def title
      t("idv.modal.#{step_name}.heading")
    end

    def header
      t("idv.modal.#{step_name}.heading")
    end

    def description
      t("idv.modal.#{step_name}.#{reason}")
    end

    def warning_message
      reason == :warning ? warning : error
    end

    def button_text
      t("idv.modal.button.#{reason}")
    end

    def button_path
      step_name == :sessions ? idv_session_path : idv_phone_path
    end

    private

    def warning
      t('idv.modal.attempts', count: remaining_attempts)
    end

    def error
      link = link_to(t('idv.modal.errors.link'), '')
      t('idv.modal.errors.text', link: link)
    end
  end
end
