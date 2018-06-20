module Idv
  class SsnFailurePresenter < FailurePresenter
    attr_reader :view_context

    delegate :account_path,
             :destroy_user_session_path,
             :idv_session_path,
             :link_to,
             :t,
             to: :view_context

    def initialize(view_context:)
      super(:failure)
      @view_context = view_context
    end

    def title
      t('idv.titles.dupe')
    end

    def header
      t('idv.titles.dupe')
    end

    def description
      t('idv.messages.dupe_ssn1')
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      [try_again_step, sign_out_step, profile_step]
    end

    private

    def try_again_step
      link = link_to(t('idv.messages.jurisdiction.try_again_link'), idv_session_path)
      t('idv.messages.jurisdiction.try_again', link: link)
    end

    def sign_out_step
      link = link_to(t('idv.messages.dupe_ssn2_link'), destroy_user_session_path)
      t('idv.messages.dupe_ssn2_html', link: link)
    end

    def profile_step
      link = link_to(t('idv.messages.jurisdiction.profile_link'), account_path)
      t('idv.messages.jurisdiction.profile', link: link)
    end
  end
end
