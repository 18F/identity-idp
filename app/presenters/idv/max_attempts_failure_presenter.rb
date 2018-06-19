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
      t("idv.modal.#{step_name}.heading")
    end

    def header
      t("idv.modal.#{step_name}.heading")
    end

    def description
      t("idv.modal.#{step_name}.fail")
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      [sp_step, help_step, profile_step].compact
    end

    private

    def sp_step
      return unless (sp_name = decorated_session.sp_name)
      support_link = link_to(sp_name, decorated_session.sp_alert_learn_more)
      t('idv.messages.jurisdiction.sp_support', link: support_link)
    end

    def help_step
      help_link = link_to(
        t('idv.messages.read_about_security_and_privacy.link'),
        MarketingSite.help_privacy_and_security_url
      )
      t('idv.messages.read_about_security_and_privacy.text', link: help_link)
    end

    def profile_step
      profile_link = link_to(t('idv.messages.jurisdiction.profile_link'), account_path)
      t('idv.messages.jurisdiction.profile', link: profile_link)
    end
  end
end
