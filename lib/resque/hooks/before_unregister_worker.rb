# Adding a +before_unregister_worker+ hook Resque::Worker. To be used, must be matched by a similar monkeypatch
# for Resque class itself, or else a class that extends Resque. See apple_push_notification/queue_manager.rb for 
# an implementation.
module Resque
  class Worker
    alias_method :unregister_worker_without_before_hook, :unregister_worker

    # Wrapper for original unregister_worker method which adds a before hook +before_unregister_worker+
    # to be executed if present.
    def unregister_worker(exception = nil)
      run_hook(:before_unregister_worker, self) 
      unregister_worker_without_before_hook(exception)
    end
    
    
    # Unforunately have to override Resque::Worker's +run_hook+ method to call hook on 
    # APN::QueueManager rather on Resque directly. Any suggestions on
    # how to make this more flexible are more than welcome.
    def run_hook(name, *args)
      # gives custom APN::QueueManager hook(s) a chance to be found before looking at Resque
      return unless hooks = APN::QueueManager.send(name)

      if hooks.empty?
        return unless hooks = Resque.send(name)
      end

      msg = "Running #{name} hooks"
      msg << " with #{args.inspect}" if args.any?
      log msg

      hooks.each do |hook|
        args.any? ? hook.call(*args) : hook.call
      end
    end
    
  end
end
