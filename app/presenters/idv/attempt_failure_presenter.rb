module Idv
  class AttemptFailurePresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :remaining_attempts, :step_name

    def initialize(remaining_attempts:, step_name:)
      super(:warning)
      @remaining_attempts = remaining_attempts
      @step_name = step_name
    end

    def title
      t("idv.failure.#{step_name}.heading")
    end

    def header
      t("idv.failure.#{step_name}.heading")
    end

    def description
      t("idv.failure.#{step_name}.warning")
    end
  end
end
