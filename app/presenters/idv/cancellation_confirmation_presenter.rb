module Idv
  class CancellationConfirmationPresenter < FailurePresenter
    def initialize
      super(:failure)
    end

    def title
      I18n.t('headings.cancellations.confirmation')
    end

    def header
      I18n.t('headings.cancellations.confirmation')
    end

    def cancellation_effects
      [
        'bad things have happened',
        'other bad things also happened',
      ]
    end
  end
end
