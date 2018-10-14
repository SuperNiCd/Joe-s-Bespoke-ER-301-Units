-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local MenuHeader = require "Unit.MenuControl.Header"
local Task = require "Unit.MenuControl.Task"
local InputComparator = require "Unit.ViewControl.InputComparator"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local TimedGate = Class{}
TimedGate:include(Unit)

function TimedGate:init(args)
  args.title = "Timed Gate"
  args.mnemonic = "TG"
  Unit.init(self,args)
end

function TimedGate:onLoadGraph(pUnit,channelCount)

  --create units
  local skewedsin = self:createObject("SkewedSineEnvelope","skewedsin")
  local limiter = self:createObject("Limiter","limiter")
  local gain = self:createObject("Multiply","gain")
  local thirtyK = self:createObject("Constant","thirtyK")
  local durationSum = self:createObject("Sum","durationSum")
  local retrigSum = self:createObject("Sum","retrigSum")
  local invertVCA = self:createObject("Multiply","invertVCA")
  local feedbackVCA = self:createObject("Multiply","feedbackVCA")
  local negOne = self:createObject("Constant","negOne")
  local one = self:createObject("Constant","one")
  local feedbackConst = self:createObject("Constant","feedbackConst")
  local durationAdapter = self:createObject("ParameterAdapter","durationAdapter")
  local t1 = self:createObject("GainBias","t1")
  local t2 = self:createObject("GainBias","t2")
  local trig = self:createObject("Comparator","trig")

  trig:setTriggerMode()
  thirtyK:hardSet("Value",30000)
  negOne:hardSet("Value",-1.0)
  feedbackConst:hardSet("Value",1.0)
  durationAdapter:hardSet("Gain",1.0)
  limiter:optionSet("Type",3)
  one:hardSet("Value",1.0)
  skewedsin:hardSet("Skew",0.0)

  -- register exported ports
  self:addBranch("durs","D1",t1,"In")
  self:addBranch("durms","D2",t2,"In")

  -- connect objects
  connect(one,"Out",skewedsin,"Level")
  connect(pUnit,"In1",retrigSum,"Left")
  connect(retrigSum,"Out",trig,"In")
  connect(trig,"Out",skewedsin,"Trigger")
  connect(skewedsin,"Out",gain,"Left")
  connect(thirtyK,"Out",gain,"Right")
  connect(gain,"Out",limiter,"In")
  connect(limiter,"Out",pUnit,"Out1")
  connect(limiter,"Out",invertVCA,"Left")
  connect(negOne,"Out",invertVCA,"Right")
  connect(invertVCA,"Out",feedbackVCA,"Left")
  connect(feedbackConst,"Out",feedbackVCA,"Right")
  connect(feedbackVCA,"Out",retrigSum,"Right")

  connect(t1,"Out",durationSum,"Left")
  connect(t2,"Out",durationSum,"Right")
  connect(durationSum,"Out",durationAdapter,"In")
  tie(skewedsin,"Duration",durationAdapter,"Out")

  if channelCount>1 then
    connect(limiter,"Out",pUnit,"Out2")
  end

end

local views = {
  expanded = {"input","durs","durms"},
  collapsed = {},
}

local function intMap(min,max)
    local map = app.DialMap()
    local n = max - min + 1
    map:clear(n)
    for i=min,max do
      map:add(i)
    end
    map:setZero(0,false)
    map:setCoarse(1,false)
    map:setFine(0.25,false)
    return map
end

local secMap = intMap(0,300)

function TimedGate:onLoadViews(objects,controls)

    controls.input = InputComparator {
        button = "input",
        description = "Unit Input",
        unit = self,
        edge = objects.trig,
      }

      controls.durs = GainBias {
        button = "coarse",
        description = "Duration sec",
        branch = self:getBranch("D1"),
        gainbias = objects.t1,
        range = objects.t1,
        biasMap = secMap,
        biasUnits = app.unitSecs,
        initialBias = 0.0,
      }

      controls.durms = GainBias {
        button = "fine",
        description = "Duration msec",
        branch = self:getBranch("D2"),
        gainbias = objects.t2,
        range = objects.t2,
        biasMap = Encoder.getMap("unit"),
        biasUnits = app.unitSecs,
        initialBias = 0.5,
      }

  return views
end

local menu = {
    "setHeader",
    "ignore",
    "retrig",
    "infoHeader",
    "rename",
    "load",
    "save"
  }

  local mode = "ignore"
  
  function TimedGate:onLoadMenu(objects,controls)
  
    controls.setHeader = MenuHeader {
      description = string.format("Retrigger Mode: %s.",mode)
    }
  
    controls.ignore = Task {
      description = "ignore",
      task = function()  
        objects.feedbackConst:hardSet("Value",1.0)
         mode = "ignore"
      end
    }

    controls.retrig = Task {
        description = "extend",
        task = function()  
          objects.feedbackConst:hardSet("Value",0.0)
          mode = "extend"
        end
      }


    return menu
end

return TimedGate
