-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local InputComparator = require "Unit.ViewControl.InputComparator"
local ModeSelect = require "Unit.ViewControl.OptionControl"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ClockedRandomGate = Class{}
ClockedRandomGate:include(Unit)

function ClockedRandomGate:init(args)
  args.title = "Clocked Random Gate"
  args.mnemonic = "RG"
  Unit.init(self,args)
end

function ClockedRandomGate:onLoadGraph(pUnit, channelCount)
  -- create objects
  local tap = self:createObject("TapTempo","tap")
  tap:setBaseTempo(120)
  local clock = self:createObject("ClockInSeconds","clock")
  local tapEdge = self:createObject("Comparator","tapEdge")
  local syncEdge = self:createObject("Comparator","syncEdge")
  local width = self:createObject("ParameterAdapter","width")
  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  
  local random = self:createObject("WhiteNoise","random")
  local rectify = self:createObject("Rectify","rectify")
  local compare = self:createObject("Comparator","compare")
  local prob = self:createObject("ConstantOffset","prob")
  local probOffset = self:createObject("ParameterAdapter","probOffset")
  local thresh = self:createObject("ParameterAdapter","thresh")
  local one = self:createObject("Constant","one")
  local negOne = self:createObject("Constant","negOne")
  local sum = self:createObject("Sum","sum")
  local invert = self:createObject("Multiply","invert")
  local sh = self:createObject("TrackAndHold","sh")
  local shEdge = self:createObject("Comparator","shEdge")
  local vca = self:createObject("Multiply","vca")

  -- set parameters
  compare:hardSet("Hysteresis",0.0)
  compare:setGateMode()
  rectify:optionSet("Type",3) --full rectification
  one:hardSet("Value",1.0)
  negOne:hardSet("Value",-1.0)
  shEdge:setTriggerMode()
  thresh:hardSet("Gain",1.0)


  -- tie parameters
  tie(clock,"Period",tap,"Base Period")
  tie(clock,"Pulse Width",width,"Out")
  tie(clock,"Multiplier",multiplier,"Out")
  tie(clock,"Divider",divider,"Out")
  tie(prob,"Offset",probOffset,"Out")
  tie(compare,"Threshold",thresh,"Out")


  -- register exported ports
  self:addBranch("sync","Sync",syncEdge,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")
  self:addBranch("prob","Prob",probOffset,"In")


  -- connect objects
  connect(pUnit,"In1",tapEdge,"In")
  connect(tapEdge,"Out",tap,"In")
  --connect(clock,"Out",pUnit,"Out1")
  connect(syncEdge,"Out",clock,"Sync")
  connect(random,"Out",rectify,"In")
  connect(rectify,"Out",sh,"In")
  connect(shEdge,"Out",sh,"Track")
  connect(clock,"Out",shEdge,"In")
  connect(sh,"Out",compare,"In")
  connect(compare,"Out",vca,"Left")
  connect(clock,"Out",vca,"Right")
 

  connect(prob,"Out",invert,"Left")
  connect(negOne,"Out",invert,"Right")
  connect(invert,"Out",sum,"Left")
  connect(one,"Out",sum,"Right")
  connect(sum,"Out",thresh,"In")

  connect(vca,"Out",pUnit,"Out1")


 

  if channelCount>1 then
    connect(vca,"Out",pUnit,"Out2")
  end
end

function ClockedRandomGate:setAny()
  local map = Encoder.getMap("[1,32]")
  self.controls.mult:setBiasMap(app.unitNone,map)
  self.controls.mult:setFaderMap(app.unitNone,map)
  self.controls.div:setBiasMap(app.unitNone,map)
  self.controls.div:setFaderMap(app.unitNone,map)
end

function ClockedRandomGate:setRational()
  local map = Encoder.getMap("int[1,32]")
  self.controls.mult:setBiasMap(app.unitInteger,map)
  self.controls.mult:setFaderMap(app.unitInteger,map)
  self.controls.div:setBiasMap(app.unitInteger,map)
  self.controls.div:setFaderMap(app.unitInteger,map)
end

local menu = {"infoHeader","rename","load","save","rational"}

function ClockedRandomGate:onLoadMenu(objects,controls)
  controls.rational = ModeSelect {
    description = "Allowed Mult/Div",
    option = objects.clock:getOption("Rational"),
    choices = {"any","rational only"},
    boolean = true,
    onUpdate = function(choice)
      if choice=="any" then
        self:setAny()
      else
        self:setRational()
      end
    end
  }
  return menu
end

function ClockedRandomGate:deserialize(t)
  Unit.deserialize(self,t)
  local Serialization = require "Persist.Serialization"
  local rational = Serialization.get("objects/clock/options/Rational",t)
  if rational and rational==0 then
    self:setAny()
  end
end

local views = {
  expanded = {"tap","prob","mult","div","sync","width"},
  collapsed = {},
}

function ClockedRandomGate:onLoadViews(objects,controls)
  controls.tap = InputComparator {
    button = "clock",
    description = "Clock or Tap",
    unit = self,
    edge = objects.tapEdge,
  }

  controls.mult = GainBias {
    button = "mult",
    description = "Clock Multiplier",
    branch = self:getBranch("Multiplier"),
    gainbias = objects.multiplier,
    range = objects.multiplier,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.div = GainBias {
    button = "div",
    description = "Clock Divider",
    branch = self:getBranch("Divider"),
    gainbias = objects.divider,
    range = objects.divider,
    biasMap = Encoder.getMap("int[1,32]"),
    biasUnits = app.unitInteger,
    initialBias = 1
  }

  controls.sync = Comparator {
    button = "sync",
    description = "Sync",
    branch = self:getBranch("Sync"),
    edge = objects.syncEdge,
  }

  controls.width = GainBias {
    button = "width",
    description = "Pulse Width",
    branch = self:getBranch("width"),
    gainbias = objects.width,
    range = objects.width,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5
  }

  controls.prob = GainBias {
    button = "prob",
    description = "Gate Probability",
    branch = self:getBranch("Prob"),
    gainbias = objects.probOffset,
    range = objects.probOffset,
    biasMap = self:linMap(0,1,100),
    biasUnits = app.unitNone,
    initialBias = 1.0
  }  

  return views
end

function ClockedRandomGate:linMap(min,max,n)
  local map = app.DialMap()
  map:clear(n+1)
  local scale = (max - min)/n
  for i=0,n do
    map:add(i*scale+min)
  end
  map:setZero(-min/scale,false)
  return map
end

return ClockedRandomGate
