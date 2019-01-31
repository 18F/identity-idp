require 'rails_helper'

describe SignUpCompletionsShow do
  before do
    @user = create(:user)
  end

  subject do
    SignUpCompletionsShow.new(
      current_user: @user,
      loa3_requested: false,
      decorated_session: decorated_session,
      handoff: false,
    )
  end

  context 'with an sp session' do
    let(:decorated_session) do
      ServiceProviderSessionDecorator.new(
        sp: build_stubbed(:service_provider),
        view_context: ActionController::Base.new.view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new,
      )
    end

    describe '#service_provider_partial' do
      it 'returns show_sp path' do
        expect(subject.service_provider_partial).to eq('sign_up/completions/show_sp')
      end
    end
  end

  context 'with no sp session' do
    let(:decorated_session) do
      SessionDecorator.new
    end

    let(:create_identity) do
      create(:identity, user_id: @user.id)
    end

    describe '#service_provider_partial' do
      it 'returns show_identities path' do
        expect(subject.service_provider_partial).to eq('sign_up/completions/show_identities')
      end
    end

    describe '#identities' do
      it 'returns a users identities decorated' do
        identity = create_identity
        expect(subject.identities).to eq([identity.decorate])
      end
    end

    describe '#user_has_identities?' do
      it 'returns true if user has identities' do
        create_identity
        expect(subject.user_has_identities?).to eq(true)
      end

      it 'returns false if user has no identities' do
        expect(subject.user_has_identities?).to eq(false)
      end
    end
  end
end
