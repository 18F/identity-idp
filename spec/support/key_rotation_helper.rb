module KeyRotationHelper
  def rotate_hmac_key
    env = Identity::Hostdata.settings
    old_hmac_key = env.hmac_fingerprinter_key
    allow(env).to receive(:hmac_fingerprinter_key_queue).and_return(
      "[\"#{old_hmac_key}\"]",
    )
    allow(env).to receive(:hmac_fingerprinter_key).and_return('4' * 32)
  end

  def rotate_attribute_encryption_key(new_key = '4' * 32, new_cost = '4000$8$2$')
    env = Identity::Hostdata.settings
    old_key = env.attribute_encryption_key
    old_cost = '4000$8$4$'

    allow(Identity::Hostdata.settings).to receive(:attribute_encryption_key).and_return(new_key)
    allow(Identity::Hostdata.settings).to receive(:attribute_cost).and_return(new_cost)

    current_queue = JSON.parse(Identity::Hostdata.settings.attribute_encryption_key_queue)
    current_queue = [{ key: old_key, cost: old_cost }] + current_queue

    allow(Identity::Hostdata.settings).to receive(:attribute_encryption_key_queue).
      and_return(current_queue.to_json)
  end

  def rotate_all_keys
    rotate_attribute_encryption_key
    rotate_hmac_key
  end

  def rotate_attribute_encryption_key_with_invalid_queue
    env = Identity::Hostdata.settings
    allow(env).to receive(:attribute_encryption_key_queue).and_return(
      [{ key: 'key-that-was-never-used-in-the-past', cost: '4000$8$2$' }].to_json,
    )
    allow(env).to receive(:attribute_encryption_key).and_return('4' * 32)
  end
end
