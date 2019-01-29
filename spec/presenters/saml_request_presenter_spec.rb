require 'rails_helper'

describe SamlRequestPresenter do
  describe '#requested_attributes' do
    context 'LOA1 and bundle contains invalid attributes and LOA3 attributes' do
      it 'only returns :email' do
        request = instance_double(FakeSamlRequest)
        allow(FakeSamlRequest).to receive(:new).and_return(request)
        allow(request).to receive(:requested_authn_context).
          and_return(Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF)

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        all_attributes = %w[
          email first_name middle_name last_name dob ssn
          phone address1 address2 city state zipcode foo
        ]
        service_provider = ServiceProvider.new(attribute_bundle: all_attributes)
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq(%i[email])
      end
    end

    context 'LOA3 and bundle contains invalid attributes' do
      it 'only returns valid attributes named per the OpenId Connect spec' do
        request = FakeSamlRequest.new

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        service_provider = ServiceProvider.new(
          attribute_bundle: %w[
            email first_name middle_name last_name dob foo ssn phone
          ],
        )
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)
        valid_attributes = %i[
          email given_name name family_name birthdate social_security_number phone
        ]

        expect(presenter.requested_attributes).to eq(valid_attributes)
      end
    end

    context 'LOA3 and bundle contains multiple address attributes' do
      it 'consolidates address attributes into one :address attribute' do
        request = FakeSamlRequest.new

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        service_provider = ServiceProvider.new(
          attribute_bundle: %w[address1 address2 city state zipcode],
        )
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq([:address])
      end
    end
  end
end
