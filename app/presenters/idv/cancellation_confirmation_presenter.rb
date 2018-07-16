module Idv
  class CancellationConfirmationPresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper

    def initialize
      super(:failure)
    end

    def title
      t('headings.cancellations.confirmation')
    end

    def header
      t('headings.cancellations.confirmation')
    end

    def cancellation_effects
      [
        t('idv.cancel.warnings.warning_2'),
        t('idv.cancel.warnings.warning_3', app: APP_NAME),
        t('idv.cancel.warnings.warning_4'),
        t('idv.cancel.warnings.warning_5'),
      ]
    end
  end
end
