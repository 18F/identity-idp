module Idv
  class JurisdictionFailurePresenter < FailurePresenter

    attr_reader :jurisdiction, :reason, :view_context

    delegate :account_path,
             :decorated_session,
             :idv_jurisdiction_path,
             :link_to,
             :state_name_for_abbrev,
             :t,
             to: :view_context

    def initialize(jurisdiction:, reason:, view_context:)
      super(:failure)
      @jurisdiction = jurisdiction
      @reason = reason
      @view_context = view_context
    end

    def title
      t("idv.titles.#{reason}", **i18n_args)
    end

    def header
      t("idv.titles.#{reason}", **i18n_args)
    end

    def description
      t("idv.messages.jurisdiction.#{reason}_failure", **i18n_args)
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      [try_again_step, sp_step, profile_step].compact
    end

    private

    def i18n_args
      jurisdiction ? { state: state_name_for_abbrev(jurisdiction) } : {}
    end

    def try_again_step
      try_again_link = link_to(t('idv.messages.jurisdiction.try_again_link'), idv_jurisdiction_path)
      t('idv.messages.jurisdiction.try_again', link: try_again_link)
    end

    def sp_step
      return unless decorated_session.sp_name
      support_link = link_to(decorated_session.sp_name, decorated_session.sp_alert_learn_more)
      t('idv.messages.jurisdiction.sp_support', link: support_link)
    end

    def profile_step
      profile_link = link_to(t('idv.messages.jurisdiction.profile_link'), account_path)
      t('idv.messages.jurisdiction.profile', link: profile_link)
    end
  end
end
