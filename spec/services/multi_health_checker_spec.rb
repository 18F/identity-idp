require 'rails_helper'

RSpec.describe MultiHealthChecker do
  subject(:checker) { MultiHealthChecker.new(checkers) }

  describe '#check' do
    let(:summary_class) do
      Class.new do
        def initialize(healthy)
          @healthy = healthy
        end

        def healthy?
          @healthy
        end
      end
    end

    subject(:check) { checker.check }

    let(:healthy_checker) { double(check: summary_class.new(true)) }
    let(:unhealthy_checker) { double(check: summary_class.new(false)) }

    context 'with all healthy checkers' do
      let(:checkers) do
        {
          check_a: healthy_checker,
          check_b: healthy_checker,
        }
      end

      it 'returns a healthy result' do
        expect(check.healthy?).to eq(true)
      end

      it 'returns a JSON-ready summary' do
        json = check.as_json

        expect(json['healthy']).to eq(true)
        expect(json['statuses']['check_a']).to be
        expect(json['statuses']['check_b']).to be
      end
    end

    context 'with a single unhealthy checker' do
      let(:checkers) do
        {
          check_a: healthy_checker,
          check_b: unhealthy_checker,
        }
      end

      it 'returns a healthy result' do
        expect(check.healthy?).to eq(false)
      end
    end
  end
end
