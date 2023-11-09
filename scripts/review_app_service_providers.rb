#!/usr/bin/env ruby

require 'yaml'

dashboard_url = "https://#{ENV.fetch('CI_ENVIRONMENT_SLUG')}-review-app-dashboard.review-app.identitysandbox.gov"

hash = {
  'production' => {
    'urn:gov:gsa:openidconnect.profiles:sp:sso:gsa:dashboard' => {
      'friendly_name' => 'Dashboard',
      'agency' => 'GSA',
      'agency_id' => 2,
      'logo' => '18f.svg',
      'certs' => ['identity_dashboard_cert'],
      'return_to_sp_url' => dashboard_url,
      'redirect_uris' => [
        "#{dashboard_url}/auth/logindotgov/callback",
        dashboard_url,
      ],
      'push_notification_url' => "#{dashboard_url}/api/security_events",
    }
  }
}

puts hash.to_yaml
