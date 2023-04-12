local guppy = require("guppylib")
local rc = require("rc")

function start()
  guppy:setup(args.amountRequired, args.requestSide, args.acknowledgeSide)  
end

function stop()
  guppy:stop()
  rc.unload("guppylib")
end