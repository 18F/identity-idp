# frozen_string_literal: true

module Api
  module CsrfTokenConcern
    def add_csrf_token_header_to_response
      response.set_header('X-CSRF-Token', form_authenticity_token)
    end
  end
end
