module Rreplay
  module Format
    Format = Struct.new(:file_suffix, :serializer, :deserializer, :is_binary?)

    Json = Format.new('.json',
                      ->(str) { JSON.dump(str) },
                      ->(str) { JSON.parse(str) },
                      false,
                      )
    Msgpack = Format.new('.msgpack',
                         ->(str) { MessagePack.pack(str) },
                         ->(str) { MessagePack.unpack(str) },
                         true,
                         )

    class << self
      def of(format)
        case format.to_sym
        when :json
          Json
        when :msgpack
          Msgpack
        else
          raise "Unknown format #{format}"
        end
      end
    end
  end

end