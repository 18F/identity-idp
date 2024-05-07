# frozen_string_literal: true

module Agreements
  class BaseSeeder
    def initialize(rails_env: Rails.env, yaml_path: 'config')
      @rails_env = rails_env
      @yaml_path = yaml_path
    end

    def run
      records.each do |key, config|
        config = process_config(key, config)
        record = record_class.find_or_initialize_by(
          primary_attribute_bundle(config),
        )
        record.assign_attributes(config)
        record.save!
      rescue ActiveRecord::RecordNotFound => e
        message = "#{e.message} - #{filename}: #{key}"
        raise ActiveRecord::RecordNotFound.new(message)
      rescue ActiveRecord::RecordInvalid => e
        e.record.errors.add(:base, "Record invalid - #{filename}: #{key}")
        raise ActiveRecord::RecordInvalid.new(e.record)
      end
      after_seed
    end

    private

    attr_reader :rails_env, :yaml_path

    # The following methods need to be defined in the child class
    #
    # The model class (assumed to be nested under the Agreements module)
    # def record_class
    #   Foo
    # end
    #
    # The filename of the YAML file to be read
    # def filename
    #   'foo.yml'
    # end
    #
    # The attribute used as the primariy identifier for a given record (e.g. for
    #   IAA orders it would be both iaa_gtc_id and order_number)
    # def primary_attribute_bundle(config)
    #   { 'name' => config['name'] }
    # end
    #
    # The method to process the config so it is ready to be passed to
    #   ActiveRecord (e.g. filter for permitted keys and include top-level YAML
    #   key)
    # def process_config(key, config)
    #   config.slice(%w[allow_key1 allow_key2 allow_key3].merge(name: key)
    # end

    # Override this method to run additional code after the initial records are
    # seeded
    def after_seed; end

    def records
      file = Rails.root.join(yaml_path, filename).read
      content = ERB.new(file).result
      YAML.safe_load(content, permitted_classes: [Date]).fetch(rails_env, {})
    end
  end
end
