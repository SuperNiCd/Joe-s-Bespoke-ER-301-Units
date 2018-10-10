-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local OctaveCVShifter = Class{}
OctaveCVShifter:include(Unit)

function OctaveCVShifter:init(args)
  args.title = "Octave CV Shifter"
  args.mnemonic = "OS"
  Unit.init(self,args)
end

function OctaveCVShifter:onLoadGraph(pUnit,channelCount)

  --create units
  local offset = self:createObject("ConstantOffset","offset")
  local offsetAdapter = self:createObject("ParameterAdapter","offsetAdapter")
  local fixedGain = self:createObject("Constant","fixedGain")
  local gain = self:createObject("Multiply","gain")
  local mix = self:createObject("Sum","mix")
  local quant = self:createObject("GridQuantizer","quant")


  fixedGain:hardSet("Value",0.1)
  quant:hardSet("Levels",10)

  -- register exported ports
  self:addBranch("octave","Octave",offsetAdapter,"In")
  

  -- connect objects
  connect(pUnit,"In1",mix,"Left")
  connect(offset,"Out",gain,"Left")
  connect(fixedGain,"Out",gain,"Right")
  connect(gain,"Out",quant,"In")
  connect(quant,"Out",mix,"Right")
  connect(mix,"Out",pUnit,"Out1")
  tie(offset,"Offset",offsetAdapter,"Out")
  

  if channelCount>1 then
    connect(mix,"Out",pUnit,"Out2")
  end

end

local views = {
  expanded = {"octave"},
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

local octaveMap = intMap(-4,4)

function OctaveCVShifter:onLoadViews(objects,controls)

  controls.octave = GainBias {
    button = "octave",
    description = "Octave Offset",
    branch = self:getBranch("Octave"),
    gainbias = objects.offsetAdapter,
    range = objects.offsetAdapter,
    biasMap = octaveMap,
    biasUnits = app.unitInteger,
    initialBias = 0
  }  

  return views
end

local menu = {
  "infoHeader",
  "rename",
  "load",
  "save"
}


return OctaveCVShifter
