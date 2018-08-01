-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.ViewControl.OptionControl"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ComparatorUnit = Class{}
ComparatorUnit:include(Unit)

function ComparatorUnit:init(args)
  args.title = "Compare"
  args.mnemonic = "Cp"
  Unit.init(self,args)
end

-- creation/destruction states


function ComparatorUnit:onLoadGraph(pUnit)
  -- create objects
  local compare = self:createObject("Comparator","compare")
  local threshold = self:createObject("ParameterAdapter","threshold")
  local hysteresis = self:createObject("ParameterAdapter","hysteresis")
  -- connect inputs/outputs
  connect(pUnit,"In1",compare,"In")
  connect(compare,"Out",pUnit,"Out1")
  
  tie(compare,"Hysteresis",hysteresis,"Out")
  self:addBranch("hyst","Hyst",hysteresis,"In")
  tie(compare,"Threshold", threshold, "Out")
  self:addBranch("thresh","Thresh",threshold,"In")

end

local views = {
  expanded = {"mode","input", "thresh", "hyst"},
  collapsed = {},
  input = {"scope","input"}
}

function ComparatorUnit:onLoadViews(objects,controls)
  controls.mode = ModeSelect {
    button = "o",
    description = "Type",
    option = objects.compare:getOption("Mode"),
    choices = {"toggle","gate","trigger"},
    muteOnChange = true
  }

  controls.input = InputComparator {
    button = "input",
    description = "Unit Input",
    unit = self,
    edge = objects.compare,
  }

  controls.hyst = GainBias {
    button = "hyst",
    description = "Hysteresis",
    branch = self:getBranch("Hyst"),
    gainbias = objects.hysteresis,
    range = objects.hysteresis,
    biasMap = self:linMap(0,1,1000),
    -- biasUnits = app.unitSecs,
    initialBias = 0.03
  }

  controls.thresh = GainBias {
    button = "thresh",
    description = "Threshold",
    branch = self:getBranch("Thresh"),
    gainbias = objects.threshold,
    range = objects.threshold,
    biasMap = self:linMap(0,1.0,100),
    initialBias = 0.10
  }

  return views
end

function ComparatorUnit:linMap(min,max,n)
  local map = app.DialMap()
  map:clear(n+1)
  local scale = (max - min)/n
  for i=0,n do
    map:add(i*scale+min)
  end
  map:setZero(-min/scale,false)
  return map
end

return ComparatorUnit
