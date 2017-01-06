module KeyRotationHelper
  def rotate_hmac_key
    env = Figaro.env
    old_hmac_key = env.hmac_fingerprinter_key
    allow(env).to receive(:hmac_fingerprinter_key_queue).and_return(
      "[\"#{old_hmac_key}\"]"
    )
    allow(env).to receive(:hmac_fingerprinter_key).and_return('a-new-key')
  end

  def rotate_attribute_encryption_key
    env = Figaro.env
    old_key = env.attribute_encryption_key
    allow(env).to receive(:attribute_encryption_key_queue).and_return(
      "[\"a-new-key\", \"#{old_key}\"]"
    )
    allow(env).to receive(:attribute_encryption_key).and_return('a-new-key')
  end

  def rotate_all_keys
    rotate_attribute_encryption_key
    rotate_hmac_key
  end

  def rotate_attribute_encryption_key_with_invalid_queue
    env = Figaro.env
    allow(env).to receive(:attribute_encryption_key_queue).and_return(
      '["key-that-was-never-used-in-the-past"]'
    )
    allow(env).to receive(:attribute_encryption_key).and_return('a-new-key')
  end
end
