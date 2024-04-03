# frozen_string_literal: true

class AppArtifacts
  class MissingArtifactError < StandardError; end

  class << self
    attr_reader :store
  end

  def self.setup(&block)
    @store = Store.new.build(&block)
  end

  # Intermediate class used to build a Struct for config via DSL
  class Store
    attr_reader :artifacts

    # @yieldparam [Store] store
    # @return [Struct] an instance of a struct, the propertes are defined by the block
    def build
      @artifacts = {}

      yield self

      RedactedStruct.new(*@artifacts.keys, keyword_init: true).new(**@artifacts)
    end

    # @param [Symbol] name
    # @param [String] path
    def add_artifact(name, path)
      value = read_artifact(path)
      raise MissingArtifactError.new("missing artifact: #{path}") if value.nil?
      value = yield(value) if block_given?
      @artifacts[name] = value
      nil
    end

    private

    def read_artifact(path)
      if Identity::Hostdata.in_datacenter? && !ENV['LOGIN_SKIP_REMOTE_CONFIG']
        secrets_s3.read_file(path)
      else
        read_local_artifact(path)
      end
    end

    def read_local_artifact(path)
      formatted_path = format(path, env: 'local').delete_prefix('/')
      file_path = Rails.root.join('config', 'artifacts.example', formatted_path)
      return nil unless File.exist?(file_path)
      File.read(file_path)
    end

    def secrets_s3
      @secrets_s3 ||= Identity::Hostdata.secrets_s3
    end
  end
end
