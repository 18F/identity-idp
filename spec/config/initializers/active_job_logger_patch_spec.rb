require 'rails_helper'

# Covers config/initializers/active_job_logger_patch.rb, which overrides
# ActiveJob::Logging::LogSubscriber to standardize output and prevent sensitive
# user data from being logged.
describe ActiveJob::Logging::LogSubscriber do
  it 'overrides the default job logger to output only specified parameters in JSON format' do
    class FakeJob < ActiveJob::Base
      def perform(sensitive_param:); end
    end

    # This list corresponds to the initializer's output
    permitted_attributes = %w(
      timestamp
      event_type
      job_class
      job_queue
      job_id
      duration
    )

    # In this case, we need to assert before the action which logs, block-style to
    # match the initializer
    expect(Rails.logger).to receive(:info) do |&blk|
      output = JSON.parse(blk.call)

      # [Sidenote: The nested assertions don't seem to be reflected in the spec
      # count--perhaps because of the uncommon block format?--but reversing them
      # will show them failing as expected.]
      output.keys.each { |k| expect(permitted_attributes).to include(k) }
      expect(output.keys).to_not include('sensitive_param')
    end

    FakeJob.perform_later(sensitive_param: '111-22-3333')
  end
end
