module KeyRotationHelper
  def rotate_hmac_key
    old_hmac_key = Figaro.env.hmac_fingerprinter_key
    allow(Figaro.env).to receive(:hmac_fingerprinter_key_queue).and_return(
      "[\"#{old_hmac_key}\"]"
    )
    allow(Figaro.env).to receive(:hmac_fingerprinter_key).and_return('a-new-key')
  end

  def rotate_email_encryption_key
    old_email_key = Figaro.env.email_encryption_key
    allow(Figaro.env).to receive(:email_encryption_key_queue).and_return(
      "[\"#{old_email_key}\"]"
    )
    allow(Figaro.env).to receive(:email_encryption_key).and_return('a-new-key')
  end

  def rotate_all_keys
    rotate_email_encryption_key
    rotate_hmac_key
  end
end
