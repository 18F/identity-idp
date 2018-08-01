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
      t("idv.failure.#{step_name}.heading")
    end

    def header
      t("idv.failure.#{step_name}.heading")
    end

    def description
      t("idv.failure.#{step_name}.#{reason}")
    end

    def warning_message
      reason == :warning ? warning : error
    end

    def button_text
      t("idv.failure.button.#{reason}")
    end

    def button_path
      step_name == :sessions ? idv_session_path : idv_phone_path
    end

    private

    def warning
      t('idv.failure.attempts', count: remaining_attempts)
    end

    def error
      link = link_to(t('idv.failure.errors.link'), MarketingSite.contact_url)
      t('idv.failure.errors.text', link: link)
    end
  end
end
