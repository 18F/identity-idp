module ThreatmetrixReviewConcern
  extend ActiveSupport::Concern

  def handle_pending_threatmetrix_review
    redirect_to_threatmetrix_review if threatmetrix_review_pending?
  end

  def redirect_to_threatmetrix_review
    redirect_to idv_setup_errors_url
  end

  def threatmetrix_review_pending?
    return false unless user_fully_authenticated?
    current_user.decorate.threatmetrix_review_pending?
  end
end
