require 'rails_helper'

RSpec.describe Proofing::Socure::ReasonCodes::Importer do
  describe '#download' do
    let(:downloaded_reason_codes) do
      {
        'ProductA' => {
          'A1' => 'test1',
          'A2' => 'test2',
        },
        'ProductB' => {
          'B2' => 'test3',
        },
      }
    end

    it 'adds reason codes that do not exist', :freeze_time do
      allow(subject.api_client).to receive(:download_reason_codes)
        .and_return(downloaded_reason_codes)

      result = subject.synchronize

      expect(result.success?).to eq(true)
      expect(result.to_h[:added_reason_codes]).to include(
        'code' => 'A1',
        'group' => 'ProductA',
        'description' => 'test1',
      )

      new_reason_code = SocureReasonCode.find_by(code: 'A1')
      expect(new_reason_code.group).to eq('ProductA')
      expect(new_reason_code.description).to eq('test1')
      expect(new_reason_code.added_at).to be_within(1.second).of(Time.zone.now)
      expect(new_reason_code.deactivated_at).to be_nil
    end

    it 'deactivates reason codes that have been removed by Socure', :freeze_time do
      SocureReasonCode.create(
        code: 'C3',
        group: 'ProductC',
        description: 'test3',
        added_at: 1.day.ago,
      )

      allow(subject.api_client).to receive(:download_reason_codes)
        .and_return(downloaded_reason_codes)

      result = subject.synchronize
      expect(result.to_h[:deactivated_reason_codes]).to eq(
        [{ 'code' => 'C3', 'group' => 'ProductC', 'description' => 'test3' }],
      )

      expect(result.success?).to eq(true)

      deactivated_reason_code = SocureReasonCode.find_by(code: 'C3')
      expect(deactivated_reason_code.deactivated_at).to be_within(1.second).of(Time.zone.now)
    end

    context 'the downloaded reason codes are malformed' do
      it 'returns an unsuccessful response' do
        allow(subject.api_client).to receive(:download_reason_codes)
          .and_return('malformed response')

        result = subject.synchronize

        expect(result.success?).to eq(false)
        expect(result.to_h[:exception]).to include(
          'Expected "malformed response" to be a hash of reason codes',
        )
      end
    end

    context 'their is a networking error downloading codes' do
      it 'returns an unsuccessful response' do
        allow(subject.api_client).to receive(
          :download_reason_codes,
        ).and_raise(
          Proofing::Socure::ReasonCodes::ApiClient::ApiClientError,
          'test error',
        )

        result = subject.synchronize

        expect(result.success?).to eq(false)
        expect(result.to_h[:exception]).to eq(
          '#<Proofing::Socure::ReasonCodes::ApiClient::ApiClientError: test error>',
        )
      end
    end
  end
end
