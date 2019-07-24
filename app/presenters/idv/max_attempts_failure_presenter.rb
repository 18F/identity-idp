module Idv
  class MaxAttemptsFailurePresenter < FailurePresenter
    attr_reader :decorated_session, :step_name, :view_context

    delegate :account_path,
             :idv_session_path,
             :link_to,
             :t,
             to: :view_context

    def initialize(decorated_session:, step_name:, view_context:)
      super(:locked)
      @decorated_session = decorated_session
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
      t("idv.failure.#{step_name}.fail_html")
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      []
    end
  end
end
