require 'rails_helper'

RSpec.describe Idv::DocumentArtifactsPersister do
  let(:sp) { create(:service_provider) }
  let(:user) { create(:user) }
  let(:document_capture_session) do
    create(
      :document_capture_session,
      user:,
      issuer: sp.issuer,
      socure_docv_transaction_token: '1234',
    )
  end
  let(:docv_transaction_token) { document_capture_session.socure_docv_transaction_token }
  let(:document_metadata) do
    {
      document_number: 'D-9988',
      document_issued: '2022-02-02',
      document_expiration: '2032-02-02',
      document_jurisdiction: 'WA',
    }
  end
  let(:images) do
    [
      Idv::IdvImage.new(type: :front, value: StringIO.new('front-bytes')),
      Idv::IdvImage.new(type: :back, value: StringIO.new('back-bytes')),
    ]
  end
  let(:redis_storage) { EncryptedDocStorage::RedisStorage.new }

  subject(:persister) do
    described_class.new(document_capture_session:, docv_transaction_token:, document_metadata:)
  end

  def persist(images: self.images)
    persister.call(images:)
  end

  before do
    allow(EncryptedDocStorage::RedisStorage).to receive(:new).and_return(redis_storage)
    allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
      .and_return([sp.issuer])
  end

  after do
    DocumentArtifact.find_each do |artifact|
      redis_storage.delete_image(name: artifact.storage_name)
    end
  end

  it 'creates one artifact per image, keyed to the capture session' do
    expect { persist }.to change { document_capture_session.document_artifacts.count }
      .from(0).to(2)

    artifact = document_capture_session.document_artifacts.find_by(image_type: 'front')
    expect(artifact.storage_name).to start_with('encrypted_images/')
    expect(artifact.encryption_key).to be_present
    expect(artifact.profile_id).to be_nil
  end

  it 'encrypts each image under its own key and stores it in Redis with the TTL' do
    allow(IdentityConfig.store).to receive(:document_images_ttl_seconds).and_return(3.days.to_i)

    persist

    artifacts = document_capture_session.document_artifacts.index_by(&:image_type)
    reader = EncryptedDocStorage::DocReader.new(storage: redis_storage)
    front = reader.read(
      name: artifacts['front'].storage_name,
      encryption_key: artifacts['front'].encryption_key,
    )
    back = reader.read(
      name: artifacts['back'].storage_name,
      encryption_key: artifacts['back'].encryption_key,
    )

    expect(front).to eq('front-bytes')
    expect(back).to eq('back-bytes')
    expect(artifacts['front'].encryption_key).not_to eq(artifacts['back'].encryption_key)
    expect(redis_storage.ttl(name: artifacts['front'].storage_name))
      .to be_between(3.days.to_i - 10, 3.days.to_i)
  end

  it 'persists the document metadata encrypted, one row per capture session' do
    expect { persist }.to change { DocumentMetadata.count }.by(1)

    expect(document_capture_session.document_metadata.document_data).to eq(document_metadata)
  end

  it 'skips images without bytes' do
    persist(images: images + [Idv::IdvImage.new(type: :selfie, value: nil)])

    expect(document_capture_session.document_artifacts.pluck(:image_type))
      .to contain_exactly('front', 'back')
  end

  context 'when the initiating SP is not allow-listed for image sharing' do
    before do
      allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
        .and_return([])
    end

    it 'persists nothing and writes nothing to Redis' do
      expect(redis_storage).not_to receive(:write_image)

      expect { persist }.not_to change { [DocumentArtifact.count, DocumentMetadata.count] }
    end
  end

  context 'when document image sharing is disabled' do
    before do
      allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(false)
    end

    it 'does not persist artifacts' do
      expect { persist }.not_to change { DocumentArtifact.count }
    end
  end

  context 'when the capture session requested an mDL' do
    before { document_capture_session.request_mdl! }

    it 'does not persist artifacts' do
      expect { persist }.not_to change { DocumentArtifact.count }
    end
  end

  context 'when there is no capture session' do
    let(:document_capture_session) { nil }
    let(:docv_transaction_token) { '1234' }

    it 'no-ops' do
      expect { persist }.not_to change { DocumentArtifact.count }
    end
  end

  context 'when the capture session was deleted before persisting' do
    before do
      document_capture_session
      DocumentCaptureSession.where(id: document_capture_session.id).delete_all
    end

    it 'no-ops instead of raising' do
      expect { persist }.not_to raise_error
      expect(DocumentArtifact.count).to eq(0)
    end
  end

  context 'when the session started a newer Socure transaction' do
    let(:docv_transaction_token) { 'superseded-token' }

    before do
      create(
        :document_artifact,
        document_capture_session:,
        image_type: 'front',
        storage_name: 'newer-attempt-object',
      )
    end

    it 'does not overwrite the newer verification with the stale attempt' do
      expect(redis_storage).not_to receive(:write_image)

      persist

      front = document_capture_session.document_artifacts.find_by(image_type: 'front')
      expect(front.storage_name).to eq('newer-attempt-object')
    end
  end

  context 'when no transaction token was recorded for this attempt' do
    let(:docv_transaction_token) { nil }

    before { document_capture_session.update!(socure_docv_transaction_token: nil) }

    it 'does not persist (cannot prove which attempt the images belong to)' do
      expect { persist }.not_to change { DocumentArtifact.count }
    end
  end

  context 'when a prior failed attempt left artifacts of a different type on the session' do
    let!(:stale) { create(:document_artifact, document_capture_session:, image_type: 'passport') }

    it 'prunes the stale artifact and its stored image so only the verified document remains' do
      redis_storage.write_image(encrypted_image: 'stale', name: stale.storage_name)

      persist

      expect(document_capture_session.document_artifacts.pluck(:image_type))
        .to contain_exactly('front', 'back')
      expect(redis_storage.read_image(name: stale.storage_name)).to be_nil
    end
  end

  context 'when a previously stored type did not come back in this result set' do
    before { create(:document_artifact, document_capture_session:, image_type: 'back') }

    it 'prunes the stale row for that type rather than keeping the old object' do
      persist(images: images.reject { |image| image.type == :back })

      expect(document_capture_session.document_artifacts.pluck(:image_type))
        .to contain_exactly('front')
    end
  end

  context 'when Idv::Session already stamped this session with the profile it produced' do
    let(:profile) { create(:profile, user:) }

    before { document_capture_session.update!(profile:) }

    it 'links the artifacts and document metadata to that exact profile' do
      persist

      expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq)
        .to eq([profile.id])
      expect(document_capture_session.document_metadata.profile_id).to eq(profile.id)
    end
  end

  context 'when the stamp is written after the caller loaded the session (backlog race)' do
    let(:profile) { create(:profile, user:) }

    before do
      document_capture_session
      DocumentCaptureSession.where(id: document_capture_session.id)
        .update_all(profile_id: profile.id)
    end

    it 'still links the artifacts by reading the stamp from the locked row' do
      persist

      expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq)
        .to eq([profile.id])
    end

    it 'serializes on the capture-session row lock so a concurrent stamp is never missed' do
      expect(DocumentCaptureSession).to receive(:lock).and_call_original

      persist
    end
  end

  context 'when the user has an unrelated active profile but this session produced none' do
    before { create(:profile, :active, user:, verified_at: 1.minute.from_now) }

    it 'leaves the artifacts unlinked rather than guessing from the active profile' do
      persist

      expect(document_capture_session.document_artifacts.pluck(:profile_id).uniq).to eq([nil])
    end
  end

  context 'when run twice (job retry)' do
    let(:fresh_images) do
      [
        Idv::IdvImage.new(type: :front, value: StringIO.new('front-bytes')),
        Idv::IdvImage.new(type: :back, value: StringIO.new('back-bytes')),
      ]
    end

    it 'is idempotent and does not create duplicate artifacts' do
      persist
      expect { persist(images: fresh_images) }
        .not_to change { document_capture_session.document_artifacts.count }.from(2)
    end

    it 'replaces the stored image and removes the superseded one' do
      persist
      first_name = document_capture_session.document_artifacts.find_by(image_type: 'front')
        .storage_name

      persist(images: fresh_images)
      second_name = document_capture_session.document_artifacts.find_by(image_type: 'front')
        .storage_name

      expect(second_name).not_to eq(first_name)
      expect(redis_storage.read_image(name: first_name)).to be_nil
      expect(redis_storage.read_image(name: second_name)).to be_present
    end
  end
end
