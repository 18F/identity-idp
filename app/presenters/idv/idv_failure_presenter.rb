module Idv
  class IdvFailurePresenter < FailurePresenter
    attr_reader :view_context

    delegate :account_path,
             :decorated_session,
             :link_to,
             :t,
             to: :view_context

    def initialize(view_context:)
      super(:locked)
      @view_context = view_context
    end

    def title
      t('idv.titles.hardfail', app: APP_NAME)
    end

    def header
      t('idv.titles.hardfail', app: APP_NAME)
    end

    def description
      t('idv.messages.hardfail', hours: Figaro.env.idv_attempt_window_in_hours)
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      []
    end
  end
end
