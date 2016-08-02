class IdvController < ApplicationController
  include IdvSession

  before_action :confirm_two_factor_authenticated
  layout 'card_wide'

  def index
    # explore UX of this flow. disabled for now till we find the edge cases.
    # redirect_to idv_sessions_url if proofing_session_started?
  end
end
