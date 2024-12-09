# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `prometheus_exporter` gem.
# Please instead update this file by running `bin/tapioca gem prometheus_exporter`.


# source://prometheus_exporter//lib/prometheus_exporter/version.rb#3
module PrometheusExporter
  class << self
    # source://prometheus_exporter//lib/prometheus_exporter.rb#36
    def detect_json_serializer(preferred); end

    # @return [Boolean]
    #
    # source://prometheus_exporter//lib/prometheus_exporter.rb#45
    def has_oj?; end

    # source://prometheus_exporter//lib/prometheus_exporter.rb#25
    def hostname; end
  end
end

# source://prometheus_exporter//lib/prometheus_exporter.rb#9
PrometheusExporter::DEFAULT_BIND_ADDRESS = T.let(T.unsafe(nil), String)

# source://prometheus_exporter//lib/prometheus_exporter.rb#11
PrometheusExporter::DEFAULT_LABEL = T.let(T.unsafe(nil), Hash)

# per: https://github.com/prometheus/prometheus/wiki/Default-port-allocations
#
# source://prometheus_exporter//lib/prometheus_exporter.rb#8
PrometheusExporter::DEFAULT_PORT = T.let(T.unsafe(nil), Integer)

# source://prometheus_exporter//lib/prometheus_exporter.rb#10
PrometheusExporter::DEFAULT_PREFIX = T.let(T.unsafe(nil), String)

# source://prometheus_exporter//lib/prometheus_exporter.rb#13
PrometheusExporter::DEFAULT_REALM = T.let(T.unsafe(nil), String)

# source://prometheus_exporter//lib/prometheus_exporter.rb#12
PrometheusExporter::DEFAULT_TIMEOUT = T.let(T.unsafe(nil), Integer)

# source://prometheus_exporter//lib/prometheus_exporter.rb#15
class PrometheusExporter::OjCompat
  class << self
    # source://prometheus_exporter//lib/prometheus_exporter.rb#20
    def dump(obj); end

    # source://prometheus_exporter//lib/prometheus_exporter.rb#16
    def parse(obj); end
  end
end

# source://prometheus_exporter//lib/prometheus_exporter/version.rb#4
PrometheusExporter::VERSION = T.let(T.unsafe(nil), String)
