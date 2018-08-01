-- GLOBALS: app, connect
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Ringmod = Class{}
Ringmod:include(Unit)

function Ringmod:init(args)
  args.title = "Ring Mod"
  args.mnemonic = "RM"
  args.version = 1
  Unit.init(self,args)
end

function Ringmod:onLoadGraph(pUnit,channelCount)
 -- input, vca, sine osc

 -- create sine osc
 local modulator = self:createObject("SineOscillator","modulator")

 -- create multipliers
 local mult1 = self:createObject("Multiply","mult1")
 local mult2 = self:createObject("Multiply","mult2")

 -- create f0 gainbias & minmax
 local f0 = self:createObject("GainBias","f0")
 local f0Range = self:createObject("MinMax","f0Range")

 -- connect unit input to vca/multipler
 connect(pUnit,"In1",mult1,"Left")
 if channelCount > 1 then
    connect(pUnit,"In2",mult2,"Left")
 end 

 -- connect vca/multiplier to unit output
 connect(mult1,"Out",pUnit,"Out1")
 if channelCount > 1 then
    connect(mult2,"Out",pUnit,"Out2")
 end 

-- connect sine osc to right Inlet of vca/multiplier
connect(modulator,"Out",mult1,"Right")
if channelCount > 1 then
    connect(modulator,"Out",mult2,"Right")
end 

connect(f0,"Out",modulator,"Fundamental")
connect(f0,"Out",f0Range,"In")

self:addBranch("f0","Fundamental",f0,"In")

end

local views = {
  expanded = {"freq"},
  collapsed = {},
}

function Ringmod:onLoadViews(objects,controls)
    controls.freq = GainBias {
        button = "f0",
        description = "Fundamental",
        branch = self:getBranch("Fundamental"),
        gainbias = objects.f0,
        range = objects.f0Range,
        biasMap = Encoder.getMap("oscFreq"),
        biasUnits = app.unitHertz,
        initialBias = 200.0,
        gainMap = Encoder.getMap("freqGain"),
        scaling = app.octaveScaling
      }
  return views
end

return Ringmod
