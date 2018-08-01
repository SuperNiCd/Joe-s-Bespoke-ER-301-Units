-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local PitchControl = require "Unit.ViewControl.PitchControl"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local BespokeBPF = Class{}
BespokeBPF:include(Unit)

function BespokeBPF:init(args)
  args.title = "Bespoke BPF"
  args.mnemonic = "BB"
  Unit.init(self,args)
end

-- creation/destruction states

function BespokeBPF:onLoadGraph(pUnit,channelCount)
  local lpfilter = self:createObject("StereoLadderFilter","filter")
  local hpfilter = self:createObject("StereoLadderHPF","filter")
  if channelCount==2 then
    connect(pUnit,"In1",lpfilter,"Left In")
    connect(lpfilter,"Left Out",hpfilter,"Left In")
    connect(hpfilter,"Left Out",pUnit,"Out1")
    connect(pUnit,"In2",lpfilter,"Right In")
    connect(lpfilter,"Right Out",hpfilter,"Right In")
    connect(hpfilter,"Right Out",pUnit,"Out2")
  else
    connect(pUnit,"In1",lpfilter,"Left In")
    connect(lpfilter,"Left Out",hpfilter,"Left In")
    connect(hpfilter,"Left Out",pUnit,"Out1")
  end

  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")

  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")

  local res = self:createObject("GainBias","res")
  local resRange = self:createObject("MinMax","resRange")

  local clipper = self:createObject("Clipper","clipper")
  clipper:setMaximum(0.999)
  clipper:setMinimum(0)

  local bw = self:createObject("GainBias","bw")
  local bwRange = self:createObject("MinMax","bwRange")

  local negate = self:createObject("ConstantGain","negate")
  negate:hardSet("Gain",-1)

  local addBw = self:createObject("Sum","addBw")
  local subBw = self:createObject("Sum","subBw")

  connect(tune,"Out",lpfilter,"V/Oct")
  connect(tune,"Out",hpfilter,"V/Oct")
  connect(tune,"Out",tuneRange,"In")


  connect(f0,"Out",addBw,"Left")
  connect(bw,"Out",addBw,"Right")
  connect(addBw,"Out",lpfilter,"Fundamental")
  --connect(addBw,"Out",hpfilter,"Fundamental")

  connect(f0,"Out",subBw,"Left")
  connect(bw,"Out",negate,"In")
  connect(negate,"Out",subBw,"Right")
  --connect(subBw,"Out",lpfilter,"Fundamental")
  connect(subBw,"Out",hpfilter,"Fundamental")  

  connect(f0,"Out",f0Range,"In")
  connect(bw,"Out",bwRange,"In")

  connect(res, "Out",clipper,"In")
  connect(clipper,"Out",lpfilter,"Resonance")
  connect(clipper,"Out",hpfilter,"Resonance")
  connect(clipper,"Out",resRange,"In")

  self:addBranch("V/oct","V/Oct",tune,"In")
  self:addBranch("Q","Resonance",res,"In")
  self:addBranch("f0","Fundamental",f0,"In")
  self:addBranch("bw","Bandwidth",bw,"In")
end

local views = {
  expanded = {"tune","freq","resonance","bandwidth"},
  collapsed = {},
}

function BespokeBPF:onLoadViews(objects,controls)

  controls.tune = PitchControl {
    button = "V/oct",
    branch = self:getBranch("V/Oct"),
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    branch = self:getBranch("Fundamental"),
    description = "Fundamental",
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("filterFreq"),
    biasUnits = app.unitHertz,
    initialBias = 440,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.resonance = GainBias {
    button = "Q",
    branch = self:getBranch("Resonance"),
    description = "Resonance",
    gainbias = objects.res,
    range = objects.resRange,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.25,
    gainMap = Encoder.getMap("[-10,10]")
  }

  controls.bandwidth = GainBias {
    button = "bw",
    branch = self:getBranch("Bandwidth"),
    description = "Bandwidth",
    gainbias = objects.bw,
    range = objects.bwRange,
    biasMap = Encoder.getMap("filterFreq"),
    biasUnits = app.unitHertz,
    initialBias = 1,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }  

  return views
end

return BespokeBPF
