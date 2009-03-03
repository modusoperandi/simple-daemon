require File.dirname(__FILE__)+'/simple-daemon/version'
require 'fileutils'
require 'logger'


module SimpleDaemon

  class Base
    def self.classname
      underscore(name.split("::").last)
    end

    def self.pid_fn
      File.join(SimpleDaemon::PID_DIRECTORY, "#{classname}.pid")
    end

    def self.daemonize
      Controller.daemonize(self)
    end

    def self.logger
      @logger ||= Logger.new("#{SimpleDaemon::LOG_DIRECTORY}/#{classname}.log")
    end

  private

    def self.underscore(camel_cased_word)
      camel_cased_word.to_s.
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
    end
  end


  module PidFile
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end

    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i rescue nil
    end
  end


  module Controller
    def self.daemonize(daemon)
      case !ARGV.empty? && ARGV[0]
      when 'start'
        start(daemon)
      when 'stop'
        stop(daemon)
      when 'restart'
        stop(daemon)
        start(daemon)
      else
        puts "Invalid command. Please specify start, stop or restart."
        exit
      end
    end

    def self.start(daemon)
      fork do
        Process.setsid
        exit if fork
        if File.file?(daemon.pid_fn)
          puts "Pid file #{daemon.pid_fn} already exists.  Not starting."
          exit 1
        end
        PidFile.store(daemon, Process.pid)
        trap("TERM") {daemon.stop; exit}
        daemon.start
      end
      puts "Daemon started."
    end

    def self.stop(daemon)
      if !File.file?(daemon.pid_fn)
        puts "Pid file not found. Is the daemon started?"
        exit
      end
      pid = PidFile.recall(daemon)
      FileUtils.rm(daemon.pid_fn)
      pid && Process.kill("TERM", pid)
    rescue Errno::ESRCH
      puts "Pid file found, but process was not running. The daemon may have died."
    end
  end

end
