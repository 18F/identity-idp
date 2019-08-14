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
      nil
    end

    def next_steps
      []
    end

    def display_back_to_account?
      true
    end

    private

    def i18n_args
      jurisdiction ? { state: state_name_for_abbrev(jurisdiction) } : {}
    end
  end
end
