-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.ViewControl.OptionControl"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local MotionSensor = Class{}
MotionSensor:include(Unit)

function MotionSensor:init(args)
  args.title = "Motion Sensor"
  args.mnemonic = "MS"
  Unit.init(self,args)
end

-- creation/destruction states


function MotionSensor:onLoadGraph(pUnit)
  -- create objects
  local compare = self:createObject("Comparator","compare")
  local invert = self:createObject("Multiply","invert")
  local negOne = self:createObject("Constant","negOne")
  local sum = self:createObject("Sum","sum")
  local rectify = self:createObject("Rectify","rectify")
  local delay = self:createObject("Delay","delay",1)
  local env = self:createObject("EnvelopeFollower","env")
  local release = self:createObject("ParameterAdapter","release")
  local attack = self:createObject("ParameterAdapter","attack")
  local gain = self:createObject("Multiply","gain")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")

  -- set parameters
  compare:setGateMode()
  compare:hardSet("Threshold",0.010)
  compare:hardSet("Hysteresis",0.00)
  negOne:hardSet("Value",-1.0)
  rectify:optionSet("Type",3) --full rectification
  self:setMaxDelayTime(0.1)
  delay:hardSet("Left Delay",0.001)

  
  
  -- connect inputs/outputs
  connect(pUnit,"In1",sum,"Left")
  connect(pUnit,"In1",invert,"Left")
  connect(negOne,"Out",invert,"Right")
  connect(invert,"Out",delay,"Left In")
  connect(delay,"Left Out",sum,"Right")
  connect(sum,"Out",rectify,"In")
  connect(rectify,"Out",env,"In")
  connect(level,"Out",levelRange,"In")
  connect(level,"Out",gain,"Left")
  connect(env,"Out",gain,"Right")
  connect(gain,"Out",compare,"In")
  connect(compare,"Out",pUnit,"Out1")

  -- tie parameters
  tie(env,"Release Time",release,"Out")
  tie(env,"Attack Time",attack,"Out")

  -- register exported ports
  self:addBranch("release","Release",release,"In")
  self:addBranch("attack","Attack",attack,"In")
  self:addBranch("level","Level",level,"In")
  

end

local views = {
  expanded = {"input","level","attack","release","mode"},
  collapsed = {},
  input = {"scope","input"}
}

function MotionSensor:onLoadViews(objects,controls)

  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.compare,
  }

  controls.level = GainBias {
    button = "sens",
    branch = self:getBranch("Level"),
    description = "Level",
    gainbias = objects.level,
    range = objects.levelRange,
    biasMap = self:linMap(0,100,100),
    biasUnits = app.unitNone,
    initialBias = 50.0,
    gainMap = Encoder.getMap("gain"),
  }

  controls.attack = GainBias {
    button = "attack",
    description = "Attack Time",
    branch = self:getBranch("Attack"),
    gainbias = objects.attack,
    range = objects.attack,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.5
  }

  controls.release = GainBias {
    button = "release",
    description = "Release Time",
    branch = self:getBranch("Release"),
    gainbias = objects.release,
    range = objects.release,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.5
  }

  controls.mode = ModeSelect {
    button = "o",
    description = "Type",
    option = objects.compare:getOption("Mode"),
    choices = {"toggle","gate","trigger"},
    muteOnChange = true
  }


  return views
end

function MotionSensor:linMap(min,max,n)
  local map = app.DialMap()
  map:clear(n+1)
  local scale = (max - min)/n
  for i=0,n do
    map:add(i*scale+min)
  end
  map:setZero(-min/scale,false)
  return map
end

function MotionSensor:setMaxDelayTime(secs)
    local requested = Utils.round(secs,1)
    local allocated = self.objects.delay:allocateTimeUpTo(requested)
  end

return MotionSensor
