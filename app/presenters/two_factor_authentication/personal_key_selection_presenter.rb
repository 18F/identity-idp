# frozen_string_literal: true

module TwoFactorAuthentication
  class PersonalKeySelectionPresenter < SelectionPresenter
    def method
      :personal_key
    end
  end
end
