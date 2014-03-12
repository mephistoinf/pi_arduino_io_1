require 'rubygems'
require 'bundler/setup'

require 'celluloid/io'
require 'celluloid/autostart'

class PiSock
  include Celluloid::IO
  finalizer :shutdown

  MESSAGE_TERMINATOR_CHAR  = "\f"

  def initialize(host, port)
    puts "*** Connecting to RPi on #{host}:#{port}"

    @socket = TCPSocket.new(host, port) # a magic Celluloid::IO socket
    @arduino_buffer = ''

    async.run
  end

  def handle_read(msg)
    line = ''
    puts "handle_read msg [#{msg}]"
    @arduino_buffer += msg
    puts "arduino_buffer [#{@arduino_buffer}]"
    cr_pos = @arduino_buffer.index(MESSAGE_TERMINATOR_CHAR)
    if cr_pos
      puts "<cr> seen at #{cr_pos}"
      line = @arduino_buffer.slice(0..(cr_pos-1))
      @arduino_buffer = @arduino_buffer.slice((cr_pos+1)..-1)
      puts "line [#{line}]"
    end
  end

  def run
    loop do
      msg = @socket.readpartial(1024)
      puts "run msg [#{msg}]"
      async.handle_read(msg)
    end
  end

  def write_to_arduino(msg)
    puts "write #{msg}"
    @socket.write(msg)
  end

  def shutdown
    @socket.close
  rescue
  end
end

class PrefixTimer
  include Celluloid

  def initialize
    counter = 1
    every (20) do
      counter += 1
      Celluloid::Actor[:pi_sock].async.write_to_arduino("p#{counter}#{MESSAGE_TERMINATOR_CHAR}")
    end
  end
end

PiSock.supervise_as(:pi_sock,'localhost',54321)
PrefixTimer.supervise_as(:prefix_timer)
puts "Actors started"
sleep

