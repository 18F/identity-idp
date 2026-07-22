# frozen_string_literal: true

module Idv
  module PassportCardsConcern
    def passport_cards_supported?
      FeatureManagement.doc_auth_passport_cards_enabled? && in_passport_cards_allowed_bucket?
    end

    def in_passport_cards_allowed_bucket?
      ab_test_bucket(:DOC_AUTH_PASSPORT_CARDS_ALLOWED) == :doc_auth_passport_cards_allowed
    end
  end
end
