require 'rails_helper'

RSpec.describe NoRetryJobs do
  describe '#call' do
    context 'when the queue is idv, sms, or voice' do
      it 'runs' do
        %w[idv sms voice].each do |queue|
          count = 0
          NoRetryJobs.new.call(nil, nil, queue) { count += 1 }

          expect(count).to eq 1
        end
      end

      it 'sets retry to false when rescuing StandardError then raises the error' do
        %w[idv sms voice].each do |queue|
          msg = {}

          expect { NoRetryJobs.new.call(nil, msg, queue) { raise StandardError } }.
            to change { msg }.from({}).to('retry' => false).and raise_error(StandardError)
        end
      end
    end

    context 'when the queue is not idv, sms, or voice' do
      it 'does not set retry to false and raises StandardError' do
        msg = {}
        expect { NoRetryJobs.new.call(nil, msg, 'mailers') { raise StandardError } }.
          to change(msg, :keys).by([]).and raise_error(StandardError)
      end
    end
  end
end
