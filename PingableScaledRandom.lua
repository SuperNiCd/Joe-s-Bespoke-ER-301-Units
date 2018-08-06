-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Comparator = require "Unit.ViewControl.Comparator"
local GainBias = require "Unit.ViewControl.GainBias"
local Fader = require "Unit.ViewControl.Fader"
local Task = require "Unit.MenuControl.Task"
local ModeSelect = require "Unit.ViewControl.OptionControl"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local PingableScaledRandom = Class{}
PingableScaledRandom:include(Unit)

function PingableScaledRandom:init(args)
  args.title = "Pingable Scaled Random"
  args.mnemonic = "SR"
  Unit.init(self,args)
end

function PingableScaledRandom:onLoadGraph(pUnit,channelCount)

  --random block
  local random=self:createObject("WhiteNoise","random")
  local hold = self:createObject("TrackAndHold","hold")
  local edge = self:createObject("Comparator","edge")
  local scale = self:createObject("Multiply","scale")
  local scaleAmt = self:createObject("ConstantOffset","scaleAmt")
  local scaleLevel = self:createObject("ParameterAdapter","scaleLevel")
  local offset = self:createObject("ConstantOffset","offset")
  local offsetLevel = self:createObject("ParameterAdapter","offsetLevel")
  local quantize = self:createObject("GridQuantizer", "quantize")
  local quantVCA = self:createObject("Multiply", "quantVCA")
  local noQuantVCA = self:createObject("Multiply","noQuantVCA")
  local mix = self:createObject("Sum","mix")
  local quantVCASelector = self:createObject("Constant","quantVCASelector")
  local noQuantVCASelector = self:createObject("Constant","noQuantVCASelector")

  edge:setTriggerMode()
  quantVCASelector:hardSet("Value",0.0)
  noQuantVCASelector:hardSet("Value",1.0)

  tie(scaleAmt,"Offset",scaleLevel,"Out")
  tie(offset,"Offset",offsetLevel,"Out")
 

  -- connect objects
  connect(edge,"Out",hold,"Track")
  connect(random,"Out",hold,"In")
  connect(hold,"Out",quantize,"In")
  --quantized branch
  connect(quantize,"Out",quantVCA,"Left")
  connect(quantVCASelector,"Out",quantVCA,"Right")
  connect(quantVCA,"Out",mix,"Left")
  --unquantized branch
  connect(hold,"Out",noQuantVCA,"Left")
  connect(noQuantVCASelector,"Out",noQuantVCA,"Right")
  connect(noQuantVCA,"Out",mix,"Right")
  --merge branches
  connect(mix,"Out",scale,"Left")
  connect(scaleAmt,"Out",scale,"Right")
  connect(scale,"Out",offset,"In")
  connect(offset,"Out",pUnit,"Out1")

  if channelCount>1 then
    connect(offset,"Out",pUnit,"Out2")
  end

    -- register exported ports
  self:addBranch("trig","Trigger",edge,"In")
  self:addBranch("scalelvl","Scalelvl",scaleLevel,"In")
  self:addBranch("offset","Offset",offsetLevel,"In")

end

local views = {
  expanded = {"trigger","levels","scale","offset"},
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

local scaleMap = linMap(0,1,100)
local offsetMap = linMap(-1,1,100)

function PingableScaledRandom:onLoadViews(objects,controls)
  controls.trigger = Comparator {
    button = "trig",
    branch = self:getBranch("Trigger"),
    description = "Trigger",
    edge = objects.edge,
  }
  controls.scale = GainBias {
    button = "scale",
    description = "Attenuation",
    branch = self:getBranch("Scalelvl"),
    gainbias = objects.scaleLevel,
    range = objects.scaleLevel,
    biasMap = scaleMap,
    biasUnits = app.unitNone,
    initialBias = 1.0
  }  
  controls.offset = GainBias {
    button = "offset",
    description = "Offset",
    branch = self:getBranch("Offset"),
    gainbias = objects.offsetLevel,
    range = objects.offsetLevel,
    biasMap = offsetMap,
    biasUnits = app.unitNone,
    initialBias = 0.0
  }    
  controls.levels = Fader {
    button = "levels",
    description = "Quant Levels",
    param = objects.quantize:getParameter("Levels"),
    monitor = self,
    map = Encoder.getMap("int[1,256]"),
    units = app.unitInteger
  }  


  return views
end

local controlMode = "no"

local menu = {
  "setHeader",
  "setControlsNo",
  "setControlsYes",
  "infoHeader",
  "rename",
  "load",
  "save"
}

function PingableScaledRandom:onLoadMenu(objects,controls)

    controls.setHeader = MenuHeader {
      description = string.format("Quantize Output: %s.",controlMode)
    }
  
    controls.setControlsNo = Task {
      description = "no",
      task = function() self:changeControlMode("no", objects) end
    }
  
    controls.setControlsYes = Task {
      description = "yes",
      task = function() self:changeControlMode("yes", objects) end
    }
  
    return menu
 end



function PingableScaledRandom:changeControlMode(mode, objects)
  controlMode = mode
  if controlMode=="no" then
    objects.quantVCASelector:hardSet("Value",0.0)
    objects.noQuantVCASelector:hardSet("Value",1.0)
  else
    objects.quantVCASelector:hardSet("Value",1.0)
    objects.noQuantVCASelector:hardSet("Value",0.0)
  end
end  

return PingableScaledRandom
