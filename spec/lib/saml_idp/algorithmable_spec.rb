require 'spec_helper'
module SamlIdp
  describe "Algorithmable" do
    include Algorithmable

    describe "named raw algorithm" do
      def raw_algorithm
        :sha256
      end

      it "finds algorithm class" do
        algorithm.should == OpenSSL::Digest::SHA256
      end

      it "finds the name" do
        algorithm_name.should == "sha256"
      end
    end

    describe "class raw algorithm" do
      def raw_algorithm
        OpenSSL::Digest::SHA512
      end

      it "finds algorithm class" do
        algorithm.should == OpenSSL::Digest::SHA512
      end

      it "finds the name" do
        algorithm_name.should == "sha512"
      end
    end

    describe "nonexistent raw algorithm" do
      def raw_algorithm
        :sha1024
      end

      it "finds algorithm class" do
        algorithm.should == OpenSSL::Digest::SHA1
      end

      it "finds the name" do
        algorithm_name.should == "sha1"
      end
    end
  end
end
