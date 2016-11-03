class PagesController < ApplicationController
  skip_after_action :track_get_requests
  skip_before_action :verify_authenticity_token, only: [:deploy_json, :options]

  def page_not_found
    analytics.track_event(Analytics::PAGE_NOT_FOUND, path: request.path)

    render layout: false, status: 404
  end

  def privacy_policy
  end

  def deploy_json
    deploy_json_path = Rails.root.join('public', 'api', 'deploy.json')
    deploy_json = File.exist?(deploy_json_path) ? JSON.parse(File.read(deploy_json_path)) : {}

    render json: deploy_json
  end

  # For CORS preflight requests
  def options
    render nothing: true
  end
end
