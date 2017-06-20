class DelegatedProofingController < ApplicationController
  before_action :require_authorized_api_client

  def create
    result = delegated_proofing_form.submit

    if result.success?
      render json: { success: true }
    else
      render json: {
               success: false,
               errors: result.errors,
             },
             status: :bad_request
    end
  end

  private

  def require_authorized_api_client
    return if current_service_provider.active?

    render json: { success: false },
           status: :unauthorized
  end

  def current_service_provider
    @_current_service_provider ||= ServiceProvider.from_issuer(params[:client_id])
  end

  def delegated_proofing_form
    DelegatedProofingForm.new(params)
  end
end
