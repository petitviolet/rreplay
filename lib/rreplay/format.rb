module Rreplay
  module Format
    Format = Struct.new(:file_suffix, :serializer, :deserializer)

    Json = Format.new('.json',
                      ->(str) { JSON.dump(str) },
                      ->(str) { JSON.parse(str) },
                      )
    Msgpack = Format.new('.msgpack',
                         ->(str) { MessagePack.pack(str) },
                         ->(str) { MessagePack.unpack(str) },
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