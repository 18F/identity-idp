# frozen_string_literal: true

module ApplicationHelper
  # Sets the page title
  def title=(title)
    content_for(:title) { title }
  end

  class MissingTitleError < StandardError; end

  # Shows the page title, or raises
  # @return [String]
  # @raise [MissingTitleError]
  def title
    content_for(:title).presence || (raise MissingTitleError, 'Missing title')
  rescue MissingTitleError => error
    if IdentityConfig.store.raise_on_missing_title
      raise error
    else
      NewRelic::Agent.notice_error(error)
      ''
    end
  end

  def extends_layout(layout, **locals, &block)
    if block.present?
      @view_flow.get(:layout).replace capture(&block) # rubocop:disable Rails/HelperInstanceVariable
    end

    render template: "layouts/#{layout}", locals:
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def user_signing_up?
    params[:confirmation_token].present? || (
      current_user && !MfaPolicy.new(current_user).two_factor_enabled?
    )
  end

  def ial2_requested?
    resolved_authn_context_result.identity_proofing?
  end

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_account_creation')
    else
      t('links.cancel')
    end
  end

  def desktop_device?
    !BrowserCache.parse(request.user_agent).mobile?
  end
end
