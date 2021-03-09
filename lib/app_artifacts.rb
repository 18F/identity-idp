class AppArtifacts
  class MissingArtifactError < StandardError; end

  class << self
    attr_reader :store
  end

  def self.setup
    @store ||= Store.new
    yield store if block_given?
  end

  class Store
    attr_reader :artifacts

    delegate :[], to: :artifacts

    def initialize
      @artifacts = {}
    end

    def add_artifact(name, path)
      value = read_artifact(path)
      raise MissingArtifactError.new("missing artifact: #{path}") if value.nil?
      artifacts[name.to_s] = value
    end

    private

    def method_missing(method_name, *_args)
      key = method_name.to_s
      return super unless artifacts.key?(key)
      artifacts[key]
    end

    def respond_to_missing?(method_name, _include_private = nil)
      return super unless artifacts.key?(method_name.to_s)
      true
    end

    def read_artifact(path)
      if Identity::Hostdata.in_datacenter?
        secrets_s3.read_file(path)
      else
        read_local_artifact(path)
      end
    end

    def read_local_artifact(path)
      formatted_path = format(path, env: 'local').sub(%r{\A/}, '')
      file_path = Rails.root.join('config', 'artifacts.example', formatted_path)
      return nil unless File.exist?(file_path)
      File.read(file_path)
    end

    def secrets_s3
      @secrets_s3 ||= Identity::Hostdata.secrets_s3
    end
  end
end
