# frozen_string_literal: true

module ProofingAgent
  class AgentProofingSucceededPresenter
    attr_reader :agent_proofed_user

    def initialize(agent_proofed_user)
      @agent_proofed_user = agent_proofed_user
    end

    def banner_text
      I18n.t(
        'user_mailer.agent_proofing_succeeded.banner_html',
        deadline: I18n.l(deadline, format: I18n.t('time.formats.event_date')),
      )
    end

    def icon
    end

    def header_text
      I18n.t('user_mailer.agent_proofing_succeeded.header')
    end

    def body_text
      I18n.t(
        'user_mailer.agent_proofing_succeeded.body',
        verified_at: I18n.l(verified_at, format: I18n.t('time.formats.event_date')),
      )
    end

    def bullet1_text
      I18n.t('user_mailer.agent_proofing_succeeded.bullet1_html')
    end

    def bullet2_text
      I18n.t('user_mailer.agent_proofing_succeeded.bullet2')
    end

    def bullet3_text
      I18n.t('user_mailer.agent_proofing_succeeded.bullet3')
    end

    def cta_text
      I18n.t('user_mailer.agent_proofing_succeeded.cta')
    end

    def confirmation_url
      # build this using transaction_id? something like:
      #
      # activation_flow_url(
      #   transaction_id: transaction_id,
      #   locale: @locale,
      # )
      'https://example.com'
    end

    def footer_text
      I18n.t('user_mailer.agent_proofing_succeeded.footer_html')
    end

    def help_text
      I18n.t('user_mailer.agent_proofing_succeeded.help_html')
    end

    def transaction_id
      agent_proofed_user.transaction_id
    end

    def deadline
      verified_at + 48.hours
    end

    def verified_at
      utc = Time.zone.parse(agent_proofed_user.verified_at)
      to_system_timezone(utc)
    end

    def to_system_timezone(time_in_utc)
      time_in_utc.getlocal('-05:00')
    end
  end
end
