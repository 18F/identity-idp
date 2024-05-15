require 'rails_helper'

RSpec.describe SignInDurationConcern, type: :controller do
  let(:test_class) do
    Class.new do
      include SignInDurationConcern

      attr_reader :session

      def initialize(session = {})
        @session = session
      end
    end
  end

  let(:instance) { test_class.new }

  describe '#sign_in_duration_seconds' do
    let(:sign_in_page_visited_at) {}
    around do |example|
      freeze_time { example.run }
    end

    before do
      instance.session[:sign_in_page_visited_at] = sign_in_page_visited_at
    end

    context 'when session value is assigned' do
      let(:sign_in_page_visited_at) { 6.seconds.ago.to_s }
      it 'returns seconds since value' do
        expect(instance.sign_in_duration_seconds).to eq(6)
      end
    end

    context 'when session value is not assigned' do
      let(:sign_in_page_visited_at) { nil }
      it 'returns nil' do
        expect(instance.sign_in_duration_seconds).to be_nil
      end
    end
  end
end
