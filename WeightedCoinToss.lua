-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Comparator = require "Unit.ViewControl.Comparator"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local WeightedCoinToss = Class{}
WeightedCoinToss:include(Unit)

function WeightedCoinToss:init(args)
  args.title = "Weighted Coin Toss"
  args.mnemonic = "TC"
  Unit.init(self,args)
end

function WeightedCoinToss:onLoadGraph(pUnit,channelCount)

  --random block
  local random=self:createObject("WhiteNoise","random")
  local hold = self:createObject("TrackAndHold","hold")
  local edge = self:createObject("Comparator","edge")
  local rectify = self:createObject("Rectify","rectify")
  
  -- probability control block
  local prob = self:createObject("ConstantOffset","prob")
  local probOffset = self:createObject("ParameterAdapter","probOffset")
  local one = self:createObject("Constant","one")
  local negOne = self:createObject("Constant","negOne")
  local sum1 = self:createObject("Sum","sum")
  local invert = self:createObject("Multiply","invert")
  local thresh = self:createObject("ParameterAdapter","thresh")

  -- comparison block
  local compare = self:createObject("Comparator","compare")
  local thresh = self:createObject("ParameterAdapter","thresh")
  local reset = self:createObject("Comparator","reset")
  local sum = self:createObject("Sum","sum")
  local flip = self:createObject("Multiply","flip")

  -- output control
  local outputNegOne = self:createObject("Constant","outputNegOne")
  local outputOffset = self:createObject("ConstantOffset","outputOffset")
  local outputVCA = self:createObject("Multiply","outputVCA")


  edge:setTriggerMode()
  compare:setGateMode()
  reset:setTriggerMode()
  rectify:optionSet("Type",3) --full rectification
  one:hardSet("Value",1.0)
  negOne:hardSet("Value",-1.0)
  thresh:hardSet("Gain",1.0)
  outputNegOne:hardSet("Value",1.0)
  outputOffset:hardSet("Offset",0.0)

  -- register exported ports
  self:addBranch("trig","Trigger",edge,"In")
  self:addBranch("prob","Prob",probOffset,"In")

  -- connect objects
  connect(edge,"Out",hold,"Track")
  connect(random,"Out",rectify,"In")
  connect(rectify,"Out",hold,"In")
  connect(hold,"Out",sum,"Left")

  connect(edge,"Out",reset,"In")
  connect(reset,"Out",flip,"Left")
  connect(negOne,"Out",flip,"Right")
  connect(flip,"Out",sum,"Right")

  connect(prob,"Out",invert,"Left")
  connect(negOne,"Out",invert,"Right")
  connect(invert,"Out",sum1,"Left")
  connect(one,"Out",sum1,"Right")
  connect(sum1,"Out",thresh,"In")

  connect(sum,"Out",compare,"In")
  connect(compare,"Out",outputOffset,"In")
  connect(outputOffset,"Out",outputVCA,"Left")
  connect(outputNegOne,"Out",outputVCA,"Right")
  connect(outputVCA,"Out", pUnit,"Out1")

  if channelCount>1 then
    connect(outputVCA,"Out",pUnit,"Out2")
  end

  tie(prob,"Offset",probOffset,"Out")
  tie(compare,"Threshold",thresh,"Out")

end

local views = {
  expanded = {"trigger","prob"},
  collapsed = {},
}

local function linMap(min,max,n)
  local map = app.DialMap()
  map:clear(n+1)
  local scale = (max - min)/n
  for i=0,n do
    map:add(i*scale+min)
  end
  map:setZero(-min/scale,false)
  return map
end

local weightMap = linMap(0,1,100)

function WeightedCoinToss:onLoadViews(objects,controls)
  controls.trigger = Comparator {
    button = "trig",
    branch = self:getBranch("Trigger"),
    description = "Trigger",
    edge = objects.edge,
  }

  controls.prob = GainBias {
    button = "weight",
    description = "Stack the Odds",
    branch = self:getBranch("Prob"),
    gainbias = objects.probOffset,
    range = objects.probOffset,
    biasMap = weightMap,
    biasUnits = app.unitNone,
    initialBias = 0.5
  }  

  return views
end

local menu = {
  "setHeader",
  "setZero",
  "setNegOne",
  "infoHeader",
  "rename",
  "load",
  "save"
}

local lowValue = 0

function WeightedCoinToss:onLoadMenu(objects,controls)

  controls.setHeader = MenuHeader {
    description = string.format("Low value is: %s.",lowValue)
  }

  controls.setZero = Task {
    description = "0",
    task = function()  
      objects.outputOffset:hardSet("Offset",0.0)
      objects.outputNegOne:hardSet("Value",1.0)
    end
  }

  controls.setNegOne = Task {
    description = "-1",
    task = function()  
      objects.outputOffset:hardSet("Offset",-0.5)
      objects.outputNegOne:hardSet("Value",2.0)
    end
  }

  return menu
end

return WeightedCoinToss
