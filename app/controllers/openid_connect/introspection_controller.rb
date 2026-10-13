# frozen_string_literal: true

module OpenidConnect
  class IntrospectionController < ApplicationController
    prepend_before_action :skip_session_load
    prepend_before_action :skip_session_expiration
    skip_before_action :verify_authenticity_token

    def create
      introspection_form = OpenidConnectIntrospectionForm.new(introspection_params)
      result = introspection_form.submit

      render json: introspection_form.response,
             status: (result.success? ? :ok : :unauthorized)
    end

    def options
      head :ok
    end

    def introspection_params
      params.permit(
        :client_assertion,
        :client_assertion_type,
        :client_id,
        :token,
        :token_type_hint,
      )
    end
  end
end
