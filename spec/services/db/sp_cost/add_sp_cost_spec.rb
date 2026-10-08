require 'rails_helper'

RSpec.describe Db::SpCost::AddSpCost do
  describe '.call' do
    let(:service_provider) do
      build(:service_provider)
    end

    subject(:add_sp_cost) do
      described_class.call(service_provider, cost_type, transaction_id:)
    end

    context 'with an allowed cost type' do
      let(:cost_type) { :socure_resolution }
      let(:transaction_id) { 'socure-transaction-id' }

      let(:matching_sp_costs) do
        SpCost.where(
          issuer: service_provider.issuer,
          cost_type:,
          transaction_id:,
        )
      end

      it 'creates a cost record with the supplied attributes' do
        expect { add_sp_cost }.to change(matching_sp_costs, :count).from(0).to(1)
      end
    end

    context 'with a blank cost type' do
      let(:cost_type) { nil }
      let(:transaction_id) { nil }

      it 'does not report an error' do
        expect(NewRelic::Agent).not_to receive(:notice_error)

        add_sp_cost
      end

      it 'does not create a cost record' do
        expect { add_sp_cost }.not_to change(SpCost, :count)
      end
    end

    context 'with an unknown cost type' do
      let(:cost_type) { :unknown_resolution }
      let(:transaction_id) { nil }

      it 'reports the invalid cost type' do
        expect(NewRelic::Agent).to receive(:notice_error)
          .with(instance_of(described_class::SpCostTypeError))

        add_sp_cost
      end

      it 'does not create a cost record' do
        allow(NewRelic::Agent).to receive(:notice_error)

        expect { add_sp_cost }.not_to change(SpCost, :count)
      end
    end
  end
end
