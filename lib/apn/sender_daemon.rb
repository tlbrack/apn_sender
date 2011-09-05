# Based roughly on delayed_job's delayed/command.rb
require 'rubygems'
require 'daemons'
require 'optparse'
require 'logger'

module APN
  # A wrapper designed to daemonize an APN::Sender instance to keep in running in the background.
  # Connects worker's output to a custom logger, if available.  Creates a pid file suitable for
  # monitoring with {monit}[http://mmonit.com/monit/].
  #
  # Based off delayed_job's great example, except we can be much lighter by not loading the entire
  # Rails environment.  To use in a Rails app, <code>script/generate apn_sender</code>.
  class SenderDaemon

    def initialize(args)
      @options = {:worker_count => 1, :environment => :development, :delay => 5}

      optparse = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message') do
          puts opts
		
          exit 1
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this apn_sender under ([development]/production).') do |e|
          @options[:environment] = e
        end
        opts.on('--cert-path=NAME', 'Path to directory containing apn .pem certificates.') do |path|
          @options[:cert_path] = path
        end
        opts.on('--cert-pass=PASSWORD', 'Password for the apn .pem certificates.') do |pass|
          @options[:cert_pass] = pass
        end
        opts.on('-n', '--number-of-workers=WORKERS', "Number of unique workers to spawn") do |worker_count|
          @options[:worker_count] = worker_count.to_i rescue 1
        end
        opts.on('-v', '--verbose', "Turn on verbose mode") do
          @options[:verbose] = true
        end
        opts.on('-V', '--very-verbose', "Turn on very verbose mode") do
          @options[:very_verbose] = true
        end
        opts.on('-d', '--delay=D', "Delay between rounds of work (seconds)") do |d|
          @options[:delay] = d
        end
        opts.on('-a', '--app=NAME', 'Specifies the application for this apn_sender') do |a|
          @options[:app] = a
        end
	opts.on('-m', '--multiapp', 'Loop through all certs found in cert-path/<bundleid>/apn_[development|production].pem (not finished)') do |a|
          @options[:multiapp] = true
        end
	opts.on('-b', '--basedir=BASEDIR', 'Directory containing certs/*, logs/*, and tmp/pids/* (rather than using ::Rails.root)') do |dir|
          @options[:base_dir] = dir
        end
      end

      # If no arguments, give help screen
      @args = optparse.parse!(args.empty? ? ['-h'] : args)
      @options[:verbose] = true if @options[:very_verbose]
      @options[:base_dir] ||= ::Rails.root
      @options[:environment] ||= "development"
   
      if @options[:verbose]
	puts ":environment = #{@options[:environment]}"
	puts ":base_dir = #{@options[:base_dir]}"
	puts ":app = #{@options[:app]}"
      end
    end


    # TODO: I'm guessing a modification on this function would allow it to launch a daemon for each certificate and queue for every application bundle_id/certificate of interest.  Just gotta loop through each available certificate, setting @options[:app], @options[:environment] (which may vary from cert to cert)  and @options[:certpath] and launching the Daemon.
    def daemonize
      @options[:worker_count].times do |worker_index|
        process_name = @options[:worker_count] == 1 ? "apn_sender.#{@options[:app]}.#{@options[:environment]}" : "apn_sender.#{@options[:app]}.#{@options[:environment]}.#{worker_index}"
        #puts "#{::Rails.root}/tmp/pids"
        Daemons.run_proc(process_name, :dir => "#{@options[:base_dir]}/tmp/pids", :dir_mode => :normal, :ARGV => @args) do |*args|
          run process_name
        end
      end
    end

    def run(worker_name = nil)
      # ::Rails.root seems to be the newer way
      #puts File.join(::Rails.root, 'log', 'apn_sender.log')
      logfile = File.join(@options[:base_dir], 'log', "#{worker_name}.apnlog")
      logger = Logger.new(logfile)
      if @options[:verbose]
	      puts "logfile: #{logfile}"
      end
      #logger = Logger.new(File.join(@options[:base_dir], 'log', "#{worker_name}.apnlog"))
      worker = APN::Sender.new(@options)
      worker.logger = logger
      worker.verbose = @options[:verbose]
      worker.very_verbose = @options[:very_verbose]
      worker.work(@options[:delay])
    rescue => e
      STDERR.puts e.message

      # Put the backtrace in the log
      e.backtrace.each do |line|
        logger.debug line
      end

      logger.fatal(e) if logger && logger.respond_to?(:fatal)
      exit 1
    end

  end
end
