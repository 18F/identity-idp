require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::UsesSqsClient do
  subject(:uses_sqs_client) { Class.new.include(described_class).new }

  describe '#queue_url' do
    let(:queue_url) { 'my/test/queue/url' }
    it 'returns the queue URL from the configuration' do
      expect(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_queue_url).
        and_return(queue_url)
      expect(uses_sqs_client.queue_url).to be(queue_url)
    end
  end

  describe '#sqs_client' do
    it 'returns the same SQS client on successive calls' do
      double_client = instance_double(Aws::SQS::Client)
      allow(Aws::SQS::Client).to receive(:new).and_return(double_client).once
      expect(uses_sqs_client.sqs_client).to be(double_client)
      expect(uses_sqs_client.sqs_client).to be(double_client)
    end
  end
end
