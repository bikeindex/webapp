class ApplicationWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"
  sidekiq_options backtrace: true
end
