require_relative './random_tools.rb'

module Upaya
  module QueueConfig
    # rubocop:disable Metrics/MethodLength

    # Known acceptable values for config.active_job.queue_adapter
    KNOWN_QUEUE_ADAPTERS = %i[sidekiq inline async].freeze

    # Select a queue adapter for use, including possible random weights as
    # defined by Figaro.env.queue_adapter_weights (a JSON mapping from queue
    # adapters to integer weights)..
    def self.choose_queue_adapter
      adapter_config = Figaro.env.queue_adapter_weights

      # default to Sidekiq if no config present
      return :sidekiq unless adapter_config

      options = JSON.parse(adapter_config, symbolize_names: true)

      options.each_key do |adapter|
        unless KNOWN_QUEUE_ADAPTERS.include?(adapter)
          raise ArgumentError, "Unknown queue adapter: #{adapter.inspect}"
        end
      end

      result = Upaya::RandomTools.random_weighted_sample(options)

      logger.info("Selected config.active_job.queue_adapter = #{result.inspect}")

      result
    end

    def self.logger
      @log ||= Rails.logger || Logger.new(STDOUT)
    end

    # rubocop:enable Metrics/MethodLength
  end
end
