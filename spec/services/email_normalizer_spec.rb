require 'rails_helper'

RSpec.describe EmailNormalizer do
  subject(:normalizer) { EmailNormalizer.new(email) }

  describe '#normalized_email' do
    subject(:normalized_email) { normalizer.normalized_email }

    context 'with a non-gmail domain' do
      let(:email) { 'foobar+123@example.com' }

      it 'is the same email' do
        expect(normalized_email).to eq(email)
      end
    end

    context 'with a gmail domain' do
      let(:email) { 'foo.bar+123@gmail.com' }

      it 'removes . and anything after the +' do
        expect(normalized_email).to eq('foobar@gmail.com')
      end
    end

    context 'with a Google Apps domain' do
      let(:email) { 'foo.bar.baz+123@example.com' }
      let(:rails_offline) { false }

      before { stub_const('ENV', 'RAILS_OFFLINE' => (rails_offline ? 'TRUE' : nil)) }

      context 'in offline mode' do
        let(:rails_offline) { true }

        it 'does not make any network requests and assumes non-Google Apps' do
          expect(Resolv::DNS).to_not receive(:open)

          expect(normalized_email).to eq(email)
        end
      end

      context 'with "real DNS" enabled' do
        let(:rails_offline) { false }

        before do
          dns = instance_double(
            'Resolv::DNS',
            getresources: [
              Resolv::DNS::Resource::IN::MX.new(1, Resolv::DNS::Name.new(%w[abcd l google com])),
            ],
          )

          allow(Resolv::DNS).to receive(:open).and_yield(dns)
        end

        it 'still removes . and anything after the +' do
          expect(normalized_email).to eq('foobarbaz@example.com')
        end
      end
    end
  end
end
