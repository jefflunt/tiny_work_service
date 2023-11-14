require 'time'
require 'tiny_tcp_service'

# usage:
#  s = TinyWorkService.new(1234, 'TinyWorkService')
#  s.stop!
class TinyWorkService
  attr_reader :jobs_enqueued,
              :jobs_dequeued,
              :jobs_per_minute,
              :jobs_per_hour

  def initialize(port, label, refresh_interval_in_seconds)
    @service = TinyTCPService.new(port)
    @service.msg_handler = self
    @jobs = Queue.new
    @label = label
    @label_and_port = "#{@label}:#{port}"

    @jobs_enqueued = 0
    @jobs_dequeued = 0
    @jobs_to_track = Queue.new
    @jobs_dequeued_tracker = []

    @jobs_per_minute = 0
    @jobs_per_hour = 0

    # status printing thread
    Thread.new do
      start_time = Time.now
      print "\e[?25l" # hide cursor
      loop do
        break unless @service.running?
        sec_runtime = Time.now - start_time
        human_runtime = "%02d:%02d:%02d" % [sec_runtime / 3600, sec_runtime / 60 % 60, sec_runtime % 60]

        print "\e[1;1H"
        puts "label/port: #{@label_and_port.rjust(28)}\e[K"
        puts "time      : #{DateTime.now.iso8601.rjust(28)}\e[K"
        puts "runtime   : #{human_runtime.rjust(28)}\e[K"
        puts "workers   : #{@service.num_clients.to_s.rjust(28)}\e[K"
        puts "queue     : #{@jobs.length.to_s.rjust(28)}\e[K"
        puts "jobs/m    : #{@jobs_per_minute.to_s.rjust(28)}\e[K"
        print "jobs/h    : #{@jobs_per_hour.to_s.rjust(28)}\e[K"
        sleep refresh_interval_in_seconds
      end
      print "\e[?25h" # show cursor
    end

    # update stats thread
    Thread.new do
      loop do
        one_minute_ago = Time.now.to_i - 60
        one_hour_ago = Time.now.to_i - 3600

        # move jobs_to_track into jobs_dequeued_tracker, threadsafe
        loop do
          break if @jobs_to_track.length == 0
          @jobs_dequeued_tracker << @jobs_to_track.shift
        end

        # remove job tracking times from older than one_hour_ago
        loop do
          break if @jobs_dequeued_tracker.empty? || @jobs_dequeued_tracker.first >= one_hour_ago
          @jobs_dequeued_tracker.shift
        end

        counter = 0
        i = -1
        loop do
          break if i.abs > @jobs_dequeued_tracker.length || @jobs_dequeued_tracker[i] < one_minute_ago
          i -= 1
          counter += 1
        end
        @jobs_per_minute = counter
        @jobs_per_hour = @jobs_dequeued_tracker.count

        sleep 2
      end
    end
  end

  # interface for TinyTCPService
  def call(m)
    raise TinyTCPService::BadClient.new("nil message") if m.nil?

    case
    when m[0] == '+'        # add a job to the queue
      self << m[1..]
      'ok'                  # ok, job received
    when m[0] == '-'        # take a job from the queue
      shift || ''
    else
      raise TinyTCPService::BadClient.new("Client sent invalid message: `#{m[..50]}'")
    end
  end

  # join the service Thread, if you want to wait until it's done
  def join
    @service.join
  end

  # enqueue a job
  def <<(j)
    @jobs_enqueued += 1
    @jobs << j

    nil
  end

  # return the first job in the work queue, if there is one present
  # otherwise, return nil
  def shift
    return nil if @jobs.empty?
    @jobs_dequeued += 1
    @jobs_to_track << Time.now.to_i

    @jobs.shift
  end

  def stop!
    @service.stop!
  end
end
