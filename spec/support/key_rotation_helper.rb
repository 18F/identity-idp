module KeyRotationHelper
  def rotate_hmac_key
    env = Figaro.env
    old_hmac_key = env.hmac_fingerprinter_key
    allow(env).to receive(:hmac_fingerprinter_key_queue).and_return(
      "[\"#{old_hmac_key}\"]"
    )
    allow(env).to receive(:hmac_fingerprinter_key).and_return('a-new-key')
  end

  def rotate_attribute_encryption_key(new_key = 'a-new-key', new_cost = '4000$8$2$')
    env = Figaro.env
    old_key = env.attribute_encryption_key
    old_cost = env.attribute_cost

    allow(Figaro.env).to receive(:attribute_encryption_key).and_return(new_key)
    allow(Figaro.env).to receive(:attribute_cost).and_return(new_cost)

    current_queue = JSON.parse(Figaro.env.attribute_encryption_key_queue)
    current_queue = [{ key: old_key, cost: old_cost }] + current_queue

    allow(Figaro.env).to receive(:attribute_encryption_key_queue).
      and_return(current_queue.to_json)
  end

  def rotate_all_keys
    rotate_attribute_encryption_key
    rotate_hmac_key
  end

  def rotate_attribute_encryption_key_with_invalid_queue
    env = Figaro.env
    allow(env).to receive(:attribute_encryption_key_queue).and_return(
      [{ key: 'key-that-was-never-used-in-the-past', cost: '4000$8$2$' }].to_json
    )
    allow(env).to receive(:attribute_encryption_key).and_return('a-new-key')
  end
end
