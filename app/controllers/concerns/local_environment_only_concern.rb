# frozen_string_literal: true

# Guards a page that exists for developers and automated tests. The routes under /test are built
# only while `enable_test_routes` is on; this is the second check, inside the controller, so a
# deployed host with that setting wrong still answers 404 rather than serving the page. The page
# is served only in the development and test environments and only while the setting is on.
module LocalEnvironmentOnlyConcern
  extend ActiveSupport::Concern

  included do
    before_action :render_not_found_unless_local_environment
  end

  private

  def render_not_found_unless_local_environment
    return if Rails.env.local? && IdentityConfig.store.enable_test_routes

    render_not_found
  end
end
