# This Concern satisfies the brakeman gem "Dynamic Render Path" violation
# that is raised when rendering dynamic content in views and partials
# that come directly from params. In the below example, idv_inherited_proofing_cancel_path
# would render "/verify/inherited_proofing/cancel?step=<params[:step]>" where <params[:step]>
# == the value of params[:step], which could potentially be dangerous:
# <%= render ButtonComponent.new(action: ->(...) do
#     button_to(idv_inherited_proofing_cancel_path(step: params[:step]), ...) ...
#     end
# %>
module AllowlistedFlowStepConcern
  extend ActiveSupport::Concern

  included do
    before_action :flow_step!
  end

  private

  def flow_step!
    flow_step = flow_step_param
    unless flow_step_allowlist.include? flow_step
      Rails.logger.warn "Flow step param \"#{flow_step})\" was not whitelisted!"
      render_not_found and return
    end

    @flow_step = flow_step
  end

  # Override this method for flow step params other than params[:step]
  def flow_step_param
    params[:step]
  end

  def flow_step_allowlist
    raise NotImplementedError, '#flow_step_allowlist must be overridden'
  end
end
