-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local AliasingPulse = Class{}
AliasingPulse:include(Unit)

function AliasingPulse:init(args)
  args.title = "Bespoke Aliasing Pulse"
  args.mnemonic = "AP"
  Unit.init(self,args)
end

function AliasingPulse:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function AliasingPulse:loadMonoGraph(pUnit)
  -- create objects
  local osc = self:createObject("SineOscillator","osc")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")
  local vca = self:createObject("Multiply","vca")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")
  local bump = self:createObject("BumpMap","bump")
  local width = self:createObject("ParameterAdapter","width")
  local oscVca = self:createObject("Multiply","oscVca")
  local oscVcaMult = self:createObject("Constant","oscVcaMult")
  local compVca = self:createObject("Multiply","compVca")
  local compVcaMult = self:createObject("Constant","compVcaMult")
  local offset = self:createObject("ConstantOffset","offset")

  tie(bump,"Width",width,"Out")

  bump:hardSet("Height",1.0)
  bump:hardSet("Fade",0.0)
  oscVcaMult:hardSet("Value",0.5)
  offset:hardSet("Offset",-0.5)
  compVcaMult:hardSet("Value",2.0)

  connect(tune,"Out",tuneRange,"In")
  connect(tune,"Out",osc,"V/Oct")

  connect(f0,"Out",osc,"Fundamental")
  connect(f0,"Out",f0Range,"In")

  connect(level,"Out",levelRange,"In")
  connect(level,"Out",vca,"Left")

  connect(osc,"Out",oscVca,"Left")
  connect(oscVcaMult,"Out",oscVca,"Right")
  connect(oscVca,"Out",bump,"In")
  connect(bump,"Out",offset,"In")
  connect(offset,"Out",compVca,"Left")
  connect(compVcaMult,"Out",compVca,"Right")
  connect(compVca,"Out",vca,"Right")
  connect(vca,"Out",pUnit,"Out1")

  self:addBranch("level","Level",level,"In")
  self:addBranch("V/oct","V/Oct",tune,"In")
  self:addBranch("f0","Fundamental",f0,"In")
  self:addBranch("width","Width",width,"In")

end

function AliasingPulse:loadStereoGraph(pUnit)
  self:loadMonoGraph(pUnit)
  connect(self.objects.vca,"Out",pUnit,"Out2")
end



local views = {
  expanded = {"tune","freq","width","level"},
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
  
  local widthMap = linMap(0,1.0,100)

function AliasingPulse:onLoadViews(objects,controls)
  controls.tune = PitchControl {
    button = "V/oct",
    branch = self:getBranch("V/Oct"),
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    description = "Fundamental",
    branch = self:getBranch("Fundamental"),
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.level = GainBias {
    button = "level",
    description = "Level",
    branch = self:getBranch("Level"),
    gainbias = objects.level,
    range = objects.levelRange,
    initialBias = 1.0,
  }

  
  controls.width = GainBias {
    button = "width",
    description = "Pulse Width",
    branch = self:getBranch("Width"),
    gainbias = objects.width,
    range = objects.width,
    biasMap = widthMap,
    initialBias = 0.5,
  }



  return views
end

return AliasingPulse
