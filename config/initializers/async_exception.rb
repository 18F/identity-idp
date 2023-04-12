# Guards against accidentally turning on the broken asynchronous document capture
# feature in production. If that feature ever gets fixed, delete this file.

if Rails.env.production? && IdentityConfig.store.doc_auth_enable_presigned_s3_urls
  raise 'Cannot initialize identity-idp project with async upload turned on'
end
