module KeyRotationHelper
  def rotate_hmac_key
    old_hmac_key = IdentityConfig.store.hmac_fingerprinter_key
    allow(IdentityConfig.store).to receive(:hmac_fingerprinter_key_queue).and_return(
      [old_hmac_key.to_s],
    )
    allow(IdentityConfig.store).to receive(:hmac_fingerprinter_key).and_return('4' * 32)
  end

  def rotate_attribute_encryption_key(new_key = '4' * 32)
    old_key = IdentityConfig.store.attribute_encryption_key

    allow(IdentityConfig.store).to receive(:attribute_encryption_key).and_return(new_key)

    current_queue = IdentityConfig.store.attribute_encryption_key_queue
    current_queue = [{ 'key' => old_key }] + current_queue

    allow(IdentityConfig.store).to receive(:attribute_encryption_key_queue)
      .and_return(current_queue)
  end

  def rotate_all_keys
    rotate_attribute_encryption_key
    rotate_hmac_key
  end

  def rotate_attribute_encryption_key_with_invalid_queue
    store = IdentityConfig.store
    allow(store).to receive(:attribute_encryption_key_queue).and_return(
      [{ 'key' => 'key-that-was-never-used-in-the-past' }],
    )
    allow(store).to receive(:attribute_encryption_key).and_return('4' * 32)
  end
end
