# frozen_string_literal: true

# Initialize the prometheus exporter

if IdentityConfig.store.prometheus_exporter
  require 'prometheus_exporter/middleware'

  # This reports stats per request like HTTP status and timings
  Rails.application.middleware.unshift PrometheusExporter::Middleware
end
