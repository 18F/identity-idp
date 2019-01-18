module TwoFactorAuthCode
  class MaxAttemptsReachedPresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper
    include ActionView::Helpers::UrlHelper

    attr_reader :type, :decorated_user

    COUNTDOWN_ID = 'countdown'.freeze

    T_SCOPE = 'two_factor_authentication'.freeze

    def initialize(type, decorated_user)
      super(:locked)
      @type = type
      @decorated_user = decorated_user
    end

    def title
      t('titles.account_locked')
    end

    def header
      t('titles.account_locked')
    end

    def description
      t("max_#{type}_reached", scope: T_SCOPE)
    end

    def message
      t('headings.lock_failure')
    end

    def next_steps
      [please_try_again, read_about_two_factor_authentication]
    end

    def js
      <<~JS
        var test = #{decorated_user.lockout_time_remaining} * 1000;
        window.LoginGov.countdownTimer(document.getElementById('#{COUNTDOWN_ID}'), test);
      JS
    end

    private

    def please_try_again
      t(:please_try_again_html,
        scope: T_SCOPE, id: COUNTDOWN_ID,
        time_remaining: decorated_user.lockout_time_remaining_in_words)
    end

    def read_about_two_factor_authentication
      link = link_to(
        t('read_about_two_factor_authentication.link', scope: T_SCOPE),
        MarketingSite.help_url,
      )

      t('read_about_two_factor_authentication.text_html', scope: T_SCOPE, link: link)
    end
  end
end
