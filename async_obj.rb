require 'thread'

class AsyncObject
  attr_reader :thread,:update_frequency,:last_updated
  attr_accessor :state

  def initialize(freq)
    @update_frequency = freq
    @mutex = Mutex.new

    start
  end

  def start
    @last_updated = Time.now
    @state = :active

    @thread = Thread.new do
      keep_going = true
      while keep_going do
        @mutex.synchronize do
          keep_going = false if @state == :inactive
        end
        if keep_going
          now = Time.now
          update(@last_updated, now)
          @last_updated = now
          sleep @update_frequency
        end
      end
    end
  end

  def activate
    case @state
    when :active
      #do nothing
    when :inactive
      start
    end
  end

  def join
    @thread.join
  end

end
