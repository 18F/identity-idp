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
      [help_step, sp_step, profile_step].compact
    end

    private

    def help_step
      link_to t('idv.messages.help_center_html'), MarketingSite.help_url
    end

    def sp_step
      return unless (sp_name = decorated_session.sp_name)
      link = link_to(sp_name, decorated_session.sp_alert_learn_more)
      t('idv.messages.jurisdiction.sp_support', link: link)
    end

    def profile_step
      link = link_to(t('idv.messages.jurisdiction.profile_link'), account_path)
      t('idv.messages.jurisdiction.profile', link: link)
    end
  end
end
