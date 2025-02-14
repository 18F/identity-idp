# frozen_string_literal: true

module Idv
  module PassportConcern
    extend ActiveSupport::Concern

    def doc_auth_passports_enabled?
      IdentityConfig.store.doc_auth_passports_enabled
    end
  end
end
