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
    before do
      instance.session[:sign_in_page_visited_at] = 6.seconds.ago.to_s
    end

    it 'returns 6 seconds' do
      expect(instance.sign_in_duration_seconds).to eq(6)
    end

    it 'returns nil' do
      instance.session[:sign_in_page_visited_at] = nil
      expect(instance.sign_in_duration_seconds).to eq(nil)
    end
  end
end
