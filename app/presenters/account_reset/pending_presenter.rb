module AccountReset
  class PendingPresenter
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :account_reset_request
    attr_reader :time_remaining_until_granted

    def initialize(account_reset_request)
      @account_reset_request = account_reset_request
      @time_remaining_until_granted = description(time_remaining)
    end

    private

    def description(interval)
      desc = distance_of_time_in_words(interval)

      # when words include hours/minutes/seconds, keep only hours/minutes
      if desc.index('hour') && desc.index('second')
        desc = desc[0, desc.index('minutes') + 'minutes'.length]
      end

      # translate anything else (eg hours/min, min/seconds, seconds) as is
      translate_desc(desc)
    end

    def translate_desc(desc)
      desc.gsub(
        /(\,|and)/, " #{t('misc.and')} "
      ).sub(
        /hour(.)?/, t('time.hour') + '\1'
      ).sub(
        /minute(.)?/, t('time.minute') + '\1'
      ).sub(
        /second(.)?/, t('time.second') + '\1'
      ).squeeze(' ')
    end

    def time_remaining
      # go as low as 1 second
      interval = (account_reset_request.requested_at + 24.hours - Time.zone.now).round
      interval < 1 ? 1 : interval
    end
  end
end
