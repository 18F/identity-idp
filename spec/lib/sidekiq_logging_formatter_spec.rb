require 'rails_helper'

describe SidekiqLoggerFormatter do
  let(:job_json) do
    {
      'context' => 'Job raised exception',
      'job' => {
        'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
        'wrapped' => 'TestJob',
        'queue' => 'sms',
        'args' => [
          {
            'job_class' => 'TestJob',
            'job_id' => 'f1f1a7d1-b33a-4ce3-aa71-f3d74a1d99ae',
            'queue_name' => 'sms',
            'arguments' => ['sensitive pii'],
            'locale' => 'en'
          }
        ],
        'retry' => true,
        'jid' => '5187f014c38c66d0840633c2',
        'error_message' => 'hello world',
        'error_class' => 'RuntimeError'
      },
      'jobstr' => '{"args":"sensitive pii"}'
    }
  end

  describe '#call' do
    let(:now) { Time.current }

    it 'redacts job arguments from JSON string' do
      expect(subject.call(:WARN, now, 'job', job_json.to_json)).to_not match 'sensitive pii'
    end

    it 'redacts job arguments from Hash' do
      expect(subject.call(:WARN, now, 'job', job_json)).to_not match 'sensitive pii'
    end

    it 'leaves non-JSON string alone' do
      expect(subject.call(:WARN, now, 'job', 'sensitive pii')).to match 'sensitive pii'
    end
  end
end
