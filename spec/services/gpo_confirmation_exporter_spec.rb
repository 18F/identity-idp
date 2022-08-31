require 'rails_helper'

describe GpoConfirmationExporter do
  let(:issuer) { 'http://localhost:3000' }
  let(:service_provider) { ServiceProvider.find_by(issuer: issuer) }
  let(:confirmations) do
    [
      GpoConfirmation.new(
        entry: {
          first_name: 'John',
          last_name: 'Johnson',
          address1: '123 Sesame St',
          address2: '',
          city: 'Anytown',
          state: 'WA',
          zipcode: '98021',
          otp: 'ZYX987',
          issuer: issuer,
        },
      ),
      GpoConfirmation.new(
        entry: {
          first_name: 'Söme',
          last_name: 'Öne',
          address1: '123 Añy St',
          address2: 'Sté 123',
          city: 'Sömewhere',
          state: 'KS',
          zipcode: '66666-1234',
          otp: 'ABC123',
          issuer: '',
        },
      ),
    ]
  end

  subject { described_class.new(confirmations) }

  describe '#run' do
    before do
      allow(IdentityConfig.store).to receive(:usps_confirmation_max_days).and_return(10)
      allow(subject).to receive(:current_date).and_return(Time.zone.local(2018, 7, 6))
    end

    it 'creates psv string' do
      result = <<~HEREDOC
        01|2\r
        02|John Johnson|123 Sesame St|""|Anytown|WA|98021|ZYX987|July 6, 2018|July 16, 2018|#{service_provider.friendly_name}|#{IdentityConfig.store.domain_name}\r
        02|Söme Öne|123 Añy St|Sté 123|Sömewhere|KS|66666-1234|ABC123|July 6, 2018|July 16, 2018|Login.gov|#{IdentityConfig.store.domain_name}\r
      HEREDOC

      psv_contents = subject.run

      expect(psv_contents).to eq(result)
    end
  end
end
