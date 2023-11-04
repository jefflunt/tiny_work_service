require 'tiny_tcp_service'

# usage:
#  s = TinyWorkService.new(1234)
#  s.stop!
class TinyWorkService
  def initialize(port, label='TinyWorkService')
    @service = TinyTCPService.new(port)
    @service.msg_handler = self
    @jobs = Queue.new
    @label = label

    @thread = Thread.new do
      loop do
        break unless @service.running?

        print "\r#{@label} #{@jobs.length.to_s.rjust(6)} jobs #{@service.num_clients.to_s.rjust(4)} workers\e[K"
        sleep 0.5
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
    @thread.join
  end

  # enqueue a job
  def <<(j)
    @jobs << j
  end

  # return the first job in the work queue, if there is one present
  # otherwise, return nil
  def shift
    return nil if @jobs.empty?
    @jobs.shift
  end

  def stop!
    @service.stop!
  end
end
