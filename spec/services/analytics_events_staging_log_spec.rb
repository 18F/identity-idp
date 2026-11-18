require 'rails_helper'

RSpec.describe AnalyticsEvents do
  let(:analytics_class) do
    Class.new do
      include AnalyticsEvents

      attr_reader :tracked_event, :tracked_attributes

      def track_event(event, **attributes)
        @tracked_event = event
        @tracked_attributes = attributes
      end
    end
  end
  let(:analytics) { analytics_class.new }
  let(:proofing_results) do
    {
      context: {
        stages: {
          resolution: {
            failover_used: failover_used,
            attempted_vendors: %i[socure_kyc instant_verify_ddp],
          },
        },
      },
    }
  end
  let(:failover_used) { true }

  around do |example|
    Dir.mktmpdir do |directory|
      allow(Rails).to receive(:root).and_return(Pathname.new(directory))
      FileUtils.mkdir_p(Rails.root.join('tmp'))
      example.run
    end
  end

  before do
    allow(Identity::Hostdata).to receive(:env).and_return(deploy_env)
  end

  context 'in staging' do
    let(:deploy_env) { 'staging' }

    it 'appends the dual-vendor event to the staging log' do
      analytics.idv_doc_auth_verify_proofing_results(
        success: true,
        proofing_results:,
      )

      log = JSON.parse(
        Rails.root.join('tmp', 'dual_vendor_proofing_results.txt').read,
      )
      expect(log).to include(
        'event_name' => 'IdV: doc auth verify proofing results',
        'recorded_at' => be_present,
        'event_properties' => hash_including(
          'success' => true,
          'proofing_results' => proofing_results.deep_stringify_keys,
        ),
      )
    end

    it 'still tracks the analytics event' do
      analytics.idv_doc_auth_verify_proofing_results(
        success: true,
        proofing_results:,
      )

      expect(analytics.tracked_event).to eq('IdV: doc auth verify proofing results')
      expect(analytics.tracked_attributes).to include(success: true, proofing_results:)
    end

    context 'without failover' do
      let(:failover_used) { false }

      it 'does not create the staging log' do
        analytics.idv_doc_auth_verify_proofing_results(proofing_results:)

        expect(Rails.root.join('tmp', 'dual_vendor_proofing_results.txt')).not_to exist
      end
    end
  end

  context 'outside staging' do
    let(:deploy_env) { 'prod' }

    it 'does not create the staging log' do
      analytics.idv_doc_auth_verify_proofing_results(proofing_results:)

      expect(Rails.root.join('tmp', 'dual_vendor_proofing_results.txt')).not_to exist
    end
  end
end
