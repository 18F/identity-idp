module Api
  module CsrfTokenConcern
    def include_csrf_token_header
      response.set_header('X-CSRF-Token', form_authenticity_token)
    end
  end
end
