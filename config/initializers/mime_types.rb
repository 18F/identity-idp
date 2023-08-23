Mime::Type.register 'application/secevent+jwt', :secevent_jwt
Mime::Type.register "gzip/json", :gzip

ActionDispatch::Request.parameter_parsers[:gzip] = -> (raw_body) {
  body = ActiveSupport::Gzip.decompress(raw_body)
  JSON.parse(body).with_indifferent_access
}
