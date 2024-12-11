# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `xmldsig` gem.
# Please instead update this file by running `bin/tapioca gem xmldsig`.


# source://xmldsig//lib/xmldsig/version.rb#1
module Xmldsig; end

# source://xmldsig//lib/xmldsig/canonicalizer.rb#2
class Xmldsig::Canonicalizer
  # @return [Canonicalizer] a new instance of Canonicalizer
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#7
  def initialize(node, method = T.unsafe(nil), inclusive_namespaces = T.unsafe(nil), with_comments = T.unsafe(nil)); end

  # source://xmldsig//lib/xmldsig/canonicalizer.rb#14
  def canonicalize; end

  # Returns the value of attribute inclusive_namespaces.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def inclusive_namespaces; end

  # Sets the attribute inclusive_namespaces
  #
  # @param value the value to set the attribute inclusive_namespaces to.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def inclusive_namespaces=(_arg0); end

  # Returns the value of attribute method.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def method; end

  # Sets the attribute method
  #
  # @param value the value to set the attribute method to.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def method=(_arg0); end

  # Returns the value of attribute node.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def node; end

  # Sets the attribute node
  #
  # @param value the value to set the attribute node to.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def node=(_arg0); end

  # Returns the value of attribute with_comments.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def with_comments; end

  # Sets the attribute with_comments
  #
  # @param value the value to set the attribute with_comments to.
  #
  # source://xmldsig//lib/xmldsig/canonicalizer.rb#5
  def with_comments=(_arg0); end

  private

  # source://xmldsig//lib/xmldsig/canonicalizer.rb#20
  def mode(method); end
end

# source://xmldsig//lib/xmldsig/canonicalizer.rb#3
class Xmldsig::Canonicalizer::UnsupportedException < ::Xmldsig::Error; end

# source://xmldsig//lib/xmldsig.rb#13
class Xmldsig::Error < ::StandardError; end

# source://xmldsig//lib/xmldsig.rb#7
Xmldsig::NAMESPACES = T.let(T.unsafe(nil), Hash)

# source://xmldsig//lib/xmldsig/reference.rb#2
class Xmldsig::Reference
  # @return [Reference] a new instance of Reference
  #
  # source://xmldsig//lib/xmldsig/reference.rb#8
  def initialize(reference, id_attr = T.unsafe(nil), referenced_documents = T.unsafe(nil)); end

  # source://xmldsig//lib/xmldsig/reference.rb#61
  def calculate_digest_value; end

  # source://xmldsig//lib/xmldsig/reference.rb#71
  def digest_method; end

  # source://xmldsig//lib/xmldsig/reference.rb#57
  def digest_value; end

  # source://xmldsig//lib/xmldsig/reference.rb#85
  def digest_value=(digest_value); end

  # source://xmldsig//lib/xmldsig/reference.rb#15
  def document; end

  # Returns the value of attribute errors.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def errors; end

  # Sets the attribute errors
  #
  # @param value the value to set the attribute errors to.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def errors=(_arg0); end

  # Returns the value of attribute id_attr.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def id_attr; end

  # Sets the attribute id_attr
  #
  # @param value the value to set the attribute id_attr to.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def id_attr=(_arg0); end

  # Returns the value of attribute reference.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def reference; end

  # Sets the attribute reference
  #
  # @param value the value to set the attribute reference to.
  #
  # source://xmldsig//lib/xmldsig/reference.rb#3
  def reference=(_arg0); end

  # source://xmldsig//lib/xmldsig/reference.rb#53
  def reference_uri; end

  # source://xmldsig//lib/xmldsig/reference.rb#23
  def referenced_node; end

  # source://xmldsig//lib/xmldsig/reference.rb#19
  def sign; end

  # source://xmldsig//lib/xmldsig/reference.rb#90
  def transforms; end

  # source://xmldsig//lib/xmldsig/reference.rb#94
  def validate_digest_value; end
end

# source://xmldsig//lib/xmldsig/reference.rb#5
class Xmldsig::Reference::ReferencedNodeNotFound < ::Exception; end

# source://xmldsig//lib/xmldsig.rb#16
class Xmldsig::SchemaError < ::Xmldsig::Error; end

# source://xmldsig//lib/xmldsig/signature.rb#2
class Xmldsig::Signature
  # @return [Signature] a new instance of Signature
  #
  # source://xmldsig//lib/xmldsig/signature.rb#5
  def initialize(signature, id_attr = T.unsafe(nil), referenced_documents = T.unsafe(nil)); end

  # source://xmldsig//lib/xmldsig/signature.rb#17
  def errors; end

  # source://xmldsig//lib/xmldsig/signature.rb#11
  def references; end

  # source://xmldsig//lib/xmldsig/signature.rb#21
  def sign(private_key = T.unsafe(nil), &block); end

  # Returns the value of attribute signature.
  #
  # source://xmldsig//lib/xmldsig/signature.rb#3
  def signature; end

  # Sets the attribute signature
  #
  # @param value the value to set the attribute signature to.
  #
  # source://xmldsig//lib/xmldsig/signature.rb#3
  def signature=(_arg0); end

  # source://xmldsig//lib/xmldsig/signature.rb#30
  def signature_value; end

  # @return [Boolean]
  #
  # source://xmldsig//lib/xmldsig/signature.rb#43
  def signed?; end

  # source://xmldsig//lib/xmldsig/signature.rb#26
  def signed_info; end

  # @return [Boolean]
  #
  # source://xmldsig//lib/xmldsig/signature.rb#47
  def unsigned?; end

  # @return [Boolean]
  #
  # source://xmldsig//lib/xmldsig/signature.rb#34
  def valid?(certificate = T.unsafe(nil), schema = T.unsafe(nil), &block); end

  private

  # source://xmldsig//lib/xmldsig/signature.rb#74
  def calculate_signature_value(private_key, &block); end

  # source://xmldsig//lib/xmldsig/signature.rb#53
  def canonicalization_method; end

  # source://xmldsig//lib/xmldsig/signature.rb#57
  def canonicalized_signed_info; end

  # source://xmldsig//lib/xmldsig/signature.rb#65
  def inclusive_namespaces_for_canonicalization; end

  # source://xmldsig//lib/xmldsig/signature.rb#82
  def signature_algorithm; end

  # source://xmldsig//lib/xmldsig/signature.rb#86
  def signature_method; end

  # source://xmldsig//lib/xmldsig/signature.rb#100
  def signature_value=(signature_value); end

  # source://xmldsig//lib/xmldsig/signature.rb#111
  def validate_digest_values; end

  # @raise [Xmldsig::SchemaError]
  #
  # source://xmldsig//lib/xmldsig/signature.rb#105
  def validate_schema(schema); end

  # source://xmldsig//lib/xmldsig/signature.rb#115
  def validate_signature_value(certificate); end
end

# source://xmldsig//lib/xmldsig/signed_document.rb#2
class Xmldsig::SignedDocument
  # @return [SignedDocument] a new instance of SignedDocument
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#5
  def initialize(document, options = T.unsafe(nil)); end

  # Returns the value of attribute document.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def document; end

  # Sets the attribute document
  #
  # @param value the value to set the attribute document to.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def document=(_arg0); end

  # Returns the value of attribute force.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def force; end

  # Sets the attribute force
  #
  # @param value the value to set the attribute force to.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def force=(_arg0); end

  # Returns the value of attribute id_attr.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def id_attr; end

  # Sets the attribute id_attr
  #
  # @param value the value to set the attribute id_attr to.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def id_attr=(_arg0); end

  # Returns the value of attribute referenced_documents.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def referenced_documents; end

  # Sets the attribute referenced_documents
  #
  # @param value the value to set the attribute referenced_documents to.
  #
  # source://xmldsig//lib/xmldsig/signed_document.rb#3
  def referenced_documents=(_arg0); end

  # source://xmldsig//lib/xmldsig/signed_document.rb#20
  def sign(private_key = T.unsafe(nil), instruct = T.unsafe(nil), &block); end

  # source://xmldsig//lib/xmldsig/signed_document.rb#36
  def signatures; end

  # source://xmldsig//lib/xmldsig/signed_document.rb#32
  def signed_nodes; end

  # source://xmldsig//lib/xmldsig/signed_document.rb#16
  def validate(certificate = T.unsafe(nil), schema = T.unsafe(nil), &block); end
end

# source://xmldsig//lib/xmldsig/transforms/transform.rb#2
class Xmldsig::Transforms < ::Array
  # source://xmldsig//lib/xmldsig/transforms.rb#4
  def apply(node); end

  private

  # source://xmldsig//lib/xmldsig/transforms.rb#14
  def get_transform(node, transform_node); end
end

# source://xmldsig//lib/xmldsig/transforms/canonicalize.rb#3
class Xmldsig::Transforms::Canonicalize < ::Xmldsig::Transforms::Transform
  # source://xmldsig//lib/xmldsig/transforms/canonicalize.rb#4
  def transform; end

  private

  # source://xmldsig//lib/xmldsig/transforms/canonicalize.rb#11
  def algorithm; end

  # source://xmldsig//lib/xmldsig/transforms/canonicalize.rb#15
  def inclusive_namespaces; end
end

# source://xmldsig//lib/xmldsig/transforms/enveloped_signature.rb#3
class Xmldsig::Transforms::EnvelopedSignature < ::Xmldsig::Transforms::Transform
  # source://xmldsig//lib/xmldsig/transforms/enveloped_signature.rb#4
  def transform; end
end

# source://xmldsig//lib/xmldsig/transforms/transform.rb#3
class Xmldsig::Transforms::Transform
  # @return [Transform] a new instance of Transform
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#7
  def initialize(node, transform_node, with_comments = T.unsafe(nil)); end

  # Returns the value of attribute node.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def node; end

  # Sets the attribute node
  #
  # @param value the value to set the attribute node to.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def node=(_arg0); end

  # source://xmldsig//lib/xmldsig/transforms/transform.rb#13
  def transform; end

  # Returns the value of attribute transform_node.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def transform_node; end

  # Sets the attribute transform_node
  #
  # @param value the value to set the attribute transform_node to.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def transform_node=(_arg0); end

  # Returns the value of attribute with_comments.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def with_comments; end

  # Sets the attribute with_comments
  #
  # @param value the value to set the attribute with_comments to.
  #
  # source://xmldsig//lib/xmldsig/transforms/transform.rb#5
  def with_comments=(_arg0); end
end

# source://xmldsig//lib/xmldsig/transforms/xpath.rb#3
class Xmldsig::Transforms::XPath < ::Xmldsig::Transforms::Transform
  # @return [XPath] a new instance of XPath
  #
  # source://xmldsig//lib/xmldsig/transforms/xpath.rb#8
  def initialize(node, transform_node); end

  # source://xmldsig//lib/xmldsig/transforms/xpath.rb#13
  def transform; end

  # Returns the value of attribute xpath_query.
  #
  # source://xmldsig//lib/xmldsig/transforms/xpath.rb#4
  def xpath_query; end
end

# source://xmldsig//lib/xmldsig/transforms/xpath.rb#6
Xmldsig::Transforms::XPath::REC_XPATH_1991116_QUERY = T.let(T.unsafe(nil), String)

# source://xmldsig//lib/xmldsig/version.rb#2
Xmldsig::VERSION = T.let(T.unsafe(nil), String)

# source://xmldsig//lib/xmldsig.rb#19
Xmldsig::XSD_FILE = T.let(T.unsafe(nil), String)

# source://xmldsig//lib/xmldsig.rb#20
Xmldsig::XSD_X509_SERIAL_FIX_FILE = T.let(T.unsafe(nil), String)