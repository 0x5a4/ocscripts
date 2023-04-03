rc = require("rc")

function start()
  salmon = require("salmon")
  salmon:setup(args.port or 1000, args.timeout or 5)
end

function stop()
  salmon:shutdown()
  rc.unload("salmon")
end