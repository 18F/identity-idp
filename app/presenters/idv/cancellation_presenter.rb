module Idv
  class CancellationPresenter < FailurePresenter
    # TODO: i18n

    def initialize
      super(:warning)
    end

    def title
      'Are you sure you want to cancel'
    end

    def header
      'Are you sure you want to cancel'
    end

    def cancellation_warnings
      [
        'bad things will happen',
        'other bad things will happen'
      ]
    end
  end
end
