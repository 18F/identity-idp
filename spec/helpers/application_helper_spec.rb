require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#title' do
    let(:assigned_title) { nil }
    subject(:title) { helper.title }

    before do
      helper.title = assigned_title if assigned_title
    end

    context 'with a title assigned' do
      let(:assigned_title) { 'example' }

      it 'returns the assigned title' do
        expect(title).to eq(assigned_title)
      end
    end

    context 'without a title assigned' do
      let(:raise_on_missing_title) { nil }

      before do
        allow(IdentityConfig.store).to receive(:raise_on_missing_title).
          and_return(raise_on_missing_title)
      end

      context 'configured not to raise on missing title' do
        let(:raise_on_missing_title) { false }

        it 'returns an empty string' do
          expect(title).to eq('')
        end

        it 'notices an error' do
          expect(NewRelic::Agent).to receive(:notice_error).with(
            instance_of(ApplicationHelper::MissingTitleError),
          )

          title
        end
      end

      context 'configured to raise on missing title' do
        let(:raise_on_missing_title) { true }

        it 'raises an error' do
          expect { title }.to raise_error(ApplicationHelper::MissingTitleError)
        end
      end
    end
  end

  describe '#title=' do
    let(:title) { 'example' }

    it 'assigns the title region content' do
      helper.title = title

      expect(helper.view_flow.get(:title)).to eq(title)
    end
  end

  describe '#session_with_trust?' do
    subject(:session_with_trust) { helper.session_with_trust? }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    context 'no user present' do
      let(:user) { nil }

      it { expect(session_with_trust).to eq(false) }
    end

    context 'curent user is present' do
      let(:user) { build(:user) }

      it { expect(session_with_trust).to eq(true) }
    end
  end
end
