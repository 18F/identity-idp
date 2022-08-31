require 'rails_helper'

describe 'users/phones/add.html.erb' do
  include Devise::Test::ControllerHelpers

  subject(:rendered) { render }

  before do
    user = build_stubbed(:user)
    @new_phone_form = NewPhoneForm.new(user)
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(false)
    end

    it 'renders alert banner' do
      # rspec spec/views/users/phones/add.html.erb_spec.rb:19 to run benchmark
      require 'benchmark/ips'
      render
      render
      render

      Benchmark.ips do |x|
        x.time = 30
        x.report("no cache and recalculate") do
          @use_cache = false
          @recalculate = true
          render
        end
        x.report("cache and recalculate") do
          @use_cache = true
          @recalculate = true
          render
        end
        x.report("no cache and no recalculate") do
          @use_cache = false
          @recalculate = false
          render
        end
        x.report("cache and no recalculate") do
          @use_cache = true
          @recalculate = false
          render
        end

        x.compare!
      end
      # StackProf.run(mode: :wall, raw: true, interval: 500, out: 'tmp/stackprof-cpu-myapp.dump') do
      #   1.times do
      #     render
      #   end
      # end
    end
  end
end
