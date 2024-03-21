# initialize the prometheus exporter

if FeatureManagement.prometheus_exporter?
  require 'prometheus_exporter/middleware'

  # This reports stats per request like HTTP status and timings
  Rails.application.middleware.unshift PrometheusExporter::Middleware
end
