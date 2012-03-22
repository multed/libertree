require 'eventmachine'
require 'json'
require 'socket'
require 'gpgme'

require 'libertree/authenticatable'
require 'libertree/model'
require 'libertree/server/responder'

module Libertree
  module Server
    PORT = 14404

    include Responder

    # EventMachine callbacks

    def post_init
      port, @ip_remote = Socket.unpack_sockaddr_in(get_peername)
      puts "#{@ip_remote} connected."
    end

    def receive_data(data)
      process data
    end

    def unbind
      if @server
        @server.challenge = nil
        @server = nil
      end
    end

    # -------

    def respond(data)
      # TODO: Gracefully handle failure to convert to JSON
      send_data data.to_json
    end

    def respond_with_code(code)
      respond 'code' => code
    end

    def introduced?
      @server && @server.public_key
    end

    def self.run
      EventMachine.run do
        EventMachine.start_server '127.0.0.1', PORT, self
        puts "Libertree started."
        puts "Listening on port #{PORT}."
      end
    end
  end
end
