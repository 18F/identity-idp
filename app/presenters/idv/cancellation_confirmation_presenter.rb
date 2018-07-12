module Idv
  class CancellationConfirmationPresenter < FailurePresenter
    def initialize
      super(:failure)
    end

    def title
      'You have cancelled verifying your identity with login.gov'
    end

    def header
      'You have cancelled verifying your identity with login.gov'
    end

    def cancellation_effects
      [
        'bad things have happened',
        'other bad things also happened',
      ]
    end
  end
end
