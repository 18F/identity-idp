require 'rails_helper'

RSpec.describe Proofing::Resolution::CostRecordingProofer do
  subject(:proof) { decorator.proof(applicant) }

  let(:decorator) do
    described_class.new(
      proofer:,
      sp_cost_token:,
      current_sp:,
    )
  end
  let(:proofer) do
    instance_double(Proofing::LexisNexis::InstantVerify::Proofer)
  end
  let(:sp_cost_token) { :lexis_nexis_resolution }
  let(:current_sp) { build(:service_provider) }
  let(:applicant) { {} }
  let(:transaction_id) { 'transaction-123' }
  let(:result) do
    Proofing::Resolution::Result.new(
      success: true,
      transaction_id:,
    )
  end

  before do
    allow(proofer).to receive(:proof).with(applicant).and_return(result)
    allow(Db::SpCost::AddSpCost).to receive(:call)
  end

  it 'passes the applicant to the proofer' do
    proof

    expect(proofer).to have_received(:proof).with(applicant).once
  end

  it 'records the vendor request cost' do
    proof

    expect(Db::SpCost::AddSpCost).to have_received(:call).with(
      current_sp,
      sp_cost_token,
      transaction_id:,
    ).once
  end

  it 'returns the proofer result' do
    expect(proof).to be(result)
  end

  context 'when the vendor does not resolve the applicant' do
    let(:result) do
      Proofing::Resolution::Result.new(
        success: false,
        transaction_id:,
      )
    end

    it 'still records the vendor request cost' do
      proof

      expect(Db::SpCost::AddSpCost).to have_received(:call).with(
        current_sp,
        sp_cost_token,
        transaction_id:,
      ).once
    end
  end

  context 'when the proofer raises an exception' do
    let(:error) { RuntimeError.new('vendor request failed') }

    before do
      allow(proofer).to receive(:proof).with(applicant).and_raise(error)
    end

    it 'raises the vendor exception without recording a cost' do
      expect { proof }.to raise_error(error)
      expect(Db::SpCost::AddSpCost).not_to have_received(:call)
    end
  end

  context 'when recording the cost raises an exception' do
    let(:error) { RuntimeError.new('cost recording failed') }

    before do
      allow(Db::SpCost::AddSpCost).to receive(:call).and_raise(error)
    end

    it 'raises the cost recording exception' do
      expect { proof }.to raise_error(error)
    end
  end
end
