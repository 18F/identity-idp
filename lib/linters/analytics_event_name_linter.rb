module RuboCop
  module Cop
    module IdentityIdp
      class AnalyticsEventNameLinter < RuboCop::Cop::Cop
        RESTRICT_ON_SEND = [:track_event]

        # DO NOT ADD TO THIS LIST OR YOU WILL MAKE A KITTEN CRY!
        LEGACY_EVENT_NAMES = %w[
          f97bba7 72e5548 0a36bd8 98a6b0d 2cd5649 d39afb9 f4661b5 0245386 d8aba6e f653446 4e94ceb
          384a1f7 9a75308 9fb9eac c29fe60 907072e 4c863ee 458f9a5 eef2fc1 ec5a847 9937d84 e501af0
          81c8c81 1cea9c4 2710bff 308f5ea bae998b 0508dfa ca5aa25 527c555 2e51e29 c37f53f 9f555b9
          ad6d4bb 54d0d6b 59769e4 ebcfdca 7be355e be59e46 cb15a62 c4c3e4a d16168d c702771 ae04688
          857f289 35f9dd5 fa3a0fa daa2c12 8f9f601 361abd3 de72369 5aabbd0 7ee041a 9af4b70 d06e578
          3b0d063 d439d76 8de7256 4c5b054 587797a c35f931 a072862 cc6b97e a396d98 b118c2a 3a7ad4e
          b050e67 cb84bac a4878f9 b77cc79 d3816df 293db82 c9dfa47 f23bbfb 0add62d 5242daa ec3779d
          747cf60 27f2ae5 732940e b4fac17 32bff80 bbaa5d8 867dadb 7b0cbaa 4790e16 450d84f b60bc2b
          97c2ab4 2e7d1a7 a7ce0d7 a20ede6 515e746 a710b74 274ce1b c373ace b6b91a3 f605c20 edcc7a6
          6249b0a cba192c 9be510c 8fa5dc7 9fd6baa 4e2e21d 64ba757 f390fb8 418cada 9984089 5d9b165
          c108062 38e474a fe806c7 8e454c0 677b5d9 0b4317a 770fc14 bc1bc0b 19afc39 df43227 1086bac
          2f19ec2 a0ffc8c 3c550cf 2908eda 3dd8001 9306404 50ba274 b8051dd 638668d 59f46e9 e203c53
          3b0a7fb 7113ad2 8a495fd 53ec7c6 d8ece77 7637c9c 590bd37 77e1092 c7f8476 4b7ac07 d487486
          556f19f ee298d0 f0578cc 172a392 6b48c75 b50b9b0 6c249da be8bdeb 1ff91cc 4e58962 db81086
          d877291 82dafe0 00f9e1b 1ae5182 b648cef f2723ee 4303fd2 9e41d1a b4d10f2 bf29e20 26ceebe
          62d7044 957143a 73a72d4 d88fdb8 07800e8 9f86600 f40898e d5c9516 df93413 9c0b662 c091aa9
          f496e8b 0906c77 6439ec0 b6670dd af4401a e4fe498 2843311 857abc2 ee9f1e5 d0bca05 d37b223
          7ed9a57 a886780 6d888fa 66e1615 320993f 4f6da45 6e9c6f8 fb9c5b9 31d87f9 f6e8041 e814d71
          a3a5bfa d749026 d5c03af aa7c94f 54fe8c0 239b184 a248399 1087484 b5d0700 703c923 20d89cc
          2d736e7 4fc13f2 4fd24d1 8934e6f 3c7f45e 2d1b4d0 7cb4050 54efe76 1e6bdb4 a7f5ec7 878797c
          74e9903 34536b1 cec325a b6d7718 31723f0 d01b454 a3b78db 7a1a726 ea64de3 4c9cc98 18ea166
          e71af8e d5d8c73 c95bb0e 2e9916e 0a6fa31 474e68e 5d9ff65 eb693d9 400b55a d4c156d 9e7dc64
          5c582b2 8f4e87a 5b6d007 eb7300e 7ce9c36 fac6071 97e2876 e1e99f3 d8cf084 ab0859c 8c45e01
          5f5fca9 0e53395 ca5b5e1 5bb79a7 8004498 32f2c00 99d67ea 07598ea 027a2fc 64cb317 a8d711f
          d5f7d41 f7bcf84 5b196c2 61d039e 0f98879 ef50563 17b0399 1bd3c49 e25070a bb8e82f bcf8992
          6d672fc 760218c 5e93c76 8afa12f 08dfd0e cbfc2df 7792f12 3df9123 3d3dee4 fd14e6a 61e59e3
          5c47e81 cc9afa4 24999e1 76ffd91 a10ee5f efe4f95 670841e bb86c4a
        ].to_set.freeze

        def on_send(node)
          first_argument, = node.arguments
          expected_name = ancestor_method_name(node)
          actual_name = first_argument.value
          return if actual_name == expected_name
          return if LEGACY_EVENT_NAMES.include?(Digest::MD5.hexdigest(actual_name.to_s)[0...7])
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
