module RuboCop
  module Cop
    module IdentityIdp
      class AnalyticsEventNameLinter < RuboCop::Cop::Cop
        RESTRICT_ON_SEND = [:track_event]

        # DO NOT ADD TO THIS LIST OR YOU WILL MAKE A KITTEN CRY!
        LEGACY_EVENT_NAMES = %w[
          fa2f67e c3060a6 625c109 074a73e 1ddace4 49a1013 2e71630 feb2483 774c2e9 fcc9f02 ef39c7c
          67a6254 452df94 3d4c642 9f05438 42a4beb 8c7f423 ca5c243 1f86f19 3f5dcb7 80eb9a6 c6c20d3
          df508f2 06e295f 9479ccc 6b12f5a 236bf38 b63a840 58000bf 5045eea 9513de6 ef6d127 d9113fc
          394fda2 3fce36d 0659960 7fa7cd1 27e2f1a 63ecb4e 55860c0 d97a3d7 c25e0a3 a6b5bd0 05bccf5
          c57b9cb 86bb247 b89b4f1 df354b7 bb3e94d cb04f63 b03ccde a15c306 5c531e1 9e2d5e5 31aa7e2
          22cd3d1 414caa6 bc99baf d4389ec 889b2f9 0015f2f d618afe 6b24568 a9c1d15 f04807b 319b83c
          a381ca6 b49b3a2 e39312c fe5ffd3 404a2d7 0b50305 6ab602d f075ee0 0a6e717 1a8ab16 836a2d1
          ae328e8 491ca0e 73f8b14 1c753ed 74ace4e f92f040 045dbb2 fad0d5b e64f0c8 a3d2374 8d04135
          8c14c0a fd8ead8 672dbfa 7e9900f 2d1e4d2 294e3ae cf19350 4d95c63 607bfb7 1d43091 d14eb4d
          b8dabbe 3891860 942fe5d c62565c ba49cf4 c3aadb6 8283e0d bbb114a 42693b9 5abf6e8 c28802a
          9d17d30 b702e7e 27737a0 92d1e42 47e21a2 ef37839 a53ca41 24b7a87 b83531b f9bbcd1 ead592c
          c08f217 ceeba19 6cb85ec e8fa955 dbd33b6 e4c9313 f7ba0db 166d9f9 2fc0973 7f64dec 08057ae
          a86dcfa 91cf765 ca4ff04 73eba23 bbc673d 612d6af f70e428 7e592da 2411bc8 e18400e c55f8e7
          f703c3b 2139f3c b0c6e3c feb0ae0 c0d1995 68d050c 01407b5 48b9d7b e54cadf c445688 0480a6a
          de202d0 4f640ac 833bb3b 2714ab3 cc442c9 ef94278 3149e01 f1b713a 66566d7 12cfe99 ae7bf19
          dec4ba9 7894491 50c890f cf1a116 5af8fb2 6d3e841 b9c1844 81fd71b 2ccfec6 e4644bb c18ae37
          3a63d78 7187c0a f4fedd8 965aa71 6ebd703 a01a37c dc98bdc a1b33c6 23b7753 8506e38 fa5c68e
          1426081 f064ba3 42b5269 9dfec94 2fc3f51 b82e749 50a82ce 30a6e9d 1e9de28 9083a03 fbf06db
          6628492 0a79346 80774c2 3385dfe ad5c3f4 cc7c8b2 3a1628a 116e9dd 62d5999 a06d7ae 0598142
          8557ddc 4412ef4 245cc6b 780d115 075565e 05734b0 b4d3a07 1db82fa 0e27f2a 9543306 6646e27
          8b861cf 7cbfab2 e2ba048 e3773e8 acd0dbe 7dddb36 5fe88d2 e4d17d3 79e09c5 377c0c9 3cf0c22
          2cd4684 beefc43 452be67 3cf9b87 7376981 b78faa8 cec5d15 0957a56 a1769cf eabc949 e4173d8
          fa5332b f94ad46 96db2d8 95d1a06 1aa4b09 ccbc838 9714e09 3fc806f fc9ea0c 2f08a61 d26d285
          ce78de1 1a814b6 8d4127f a38d713 6f9ca12 faa5adf e1aac4b cd4c1af de7251b 6493d96 7a30fac
          3bcec60 93dfdf0 fd6bd3c 8335775 ac1176c 6a79836 784f40a 307f8ef f21600d 189c1bf cace681
          17e0c61 a71de38 43d6156 66a2b2d 88c7243 93818dd 393c30c eea17f7 7e17e9d 3631bdb 430f6b1
          002849f 8f19a15 afe1a04 5eaaedb 79b8cf1 7126d6b 862a03b 8bea4d5
        ].to_set.freeze

        def on_send(node)
          first_argument, = node.arguments
          expected_name = ancestor_method_name(node)
          return if first_argument.type == :sym && first_argument.value == expected_name
          return if LEGACY_EVENT_NAMES.include?(Digest::MD5.hexdigest(expected_name.to_s)[0...7])
          add_offense(
            first_argument,
            location: :expression,
            message: "Event name must match the method name, expected `:#{expected_name}`",
          )
        end

        private

        def ancestor_method_name(node)
          node.each_ancestor(:def).first.method_name
        end
      end
    end
  end
end
