# frozen_string_literal: true

# Single chrome-facing progress resolver for {ADS::PageShellComponent}.
#
# Sources (first match wins):
# 1. Opt-out via `content_for :hide_ads_progress`
# 2. IDV: `@ads_progress_component` set by `idv/shared/step_indicator`
# 3. Sign-up: route-mapped {ProgressFlow} (creation-gated)
#
# Always returns rendered HTML from a {ProgressComponent} (one typed shape).
#
module ProgressHelper
  # @return [String, nil] HTML ready for the chrome progress slot
  def ads_chrome_progress
    component = ads_progress
    render(component) if component
  end

  # @return [ProgressComponent, nil]
  def ads_progress
    return if content_for?(:hide_ads_progress)
    # Assigned in idv/shared/step_indicator for layout chrome (view → layout handoff).
    # rubocop:disable Rails/HelperInstanceVariable
    return @ads_progress_component if @ads_progress_component
    # rubocop:enable Rails/HelperInstanceVariable

    progress_from_route_map
  end

  private

  def progress_from_route_map
    position = ProgressFlow.find(progress_route_key)
    return if position.blank?
    return unless progress_visible?(position)

    ProgressComponent.new(
      steps: progress_step_labels(position.flow),
      current_step: position.step,
      current_substep: position.substep,
      substep_count: position.substeps,
      label: t('step_indicator.accessible_label'),
    )
  end

  def progress_route_key
    "#{controller_path}##{action_name}"
  end

  def progress_step_labels(flow)
    flow.step_keys.map { |key| t("#{flow.i18n_scope}.#{key}") }
  end

  def progress_visible?(position)
    return true unless position.creation_gated?

    in_account_creation_progress?
  end

  # Only show gated progress during account creation — not account-management MFA.
  def in_account_creation_progress?
    session = progress_user_session
    return false if session.blank?

    session[:in_account_creation_flow] == true
  end

  def progress_user_session
    user_session if respond_to?(:user_session, true)
  rescue Devise::MissingWarden
    nil
  end
end
