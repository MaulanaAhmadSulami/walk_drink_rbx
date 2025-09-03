local Constants = {}


-- uses by datastore
Constants.MAX_RETRIES = 3
Constants.AUTO_SAVE = 300

-- mainly uses for monetization
Constants.DWELL_TIME = 0.25
Constants.START_PART_NAME = "StarterPartStarting"
Constants.GOAL_TAG = "Goal[Example]"

--uses by payment handler
Constants.REQUEST_WINDOW_SECONDS = 3
Constants.COOLDOWN_SECONDS = 60
Constants.MAX_REQUESTS_PER_WINDOW = 3

--uses by Freeze system
Constants.FREEZE_DURATION = 60
--uses by Movement system
Constants.SPEED_DURATION = 300

--uses by progressBar
Constants.BROADCAST_INTERVAL = 0.5 -- seconds (batch rate)
Constants.MIN_DELTA = 0.02
Constants.FIRST_JOIN_DEBOUNCE = 2.0 -- seconds to ignore right after registration
Constants.MIN_RECEIVE_INTERVAL = 0.5 -- seconds, drop faster client sends

-- uses by StudSystemScript
Constants.PLUS_STUDS_DELTA = 500 --distance
Constants.MINUS_STUDS_DELTA = 500 --distance

-- uses by Checkpoint multiplier
Constants.CHECKPOINT_TAG = "Checkpoint"
Constants.CHECKPOINT_MULTIPLIER_STEP = 0.25 -- per checkpoint
Constants.CHECKPOINT_MULTIPLIER_MAX = 5.0

-- mainly use thirst system
Constants.INITIAL_THIRST = 100
Constants.MAX_THIRST = 100
Constants.RESTORE_DELAY = 5 
-- Thirst drain: reduce 1% of MAX per interval. Adjustable for gamepass holders
Constants.DRAIN_INTERVAL = 1 -- seconds (default)
Constants.DRAIN_PERCENT = 0.01 -- 1% of MAX_THIRST per tick
Constants.DRAIN_INTERVAL_GAMEPASS = 10 -- seconds for gamepass holders
Constants.REGEN_RATE = 25
Constants.NORMAL_WALKSPEED = 16
Constants.EXHAUSTED_WALKSPEED = 0

return Constants
