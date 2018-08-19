-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local ModeSelect = require "Unit.MenuControl.OptionControl"
local Encoder = require "Encoder"
local Utils = require "Utils"
local ply = app.SECTION_PLY

local Flanger = Class{}
Flanger:include(Unit)

function Flanger:init(args)
    args.title = "Flanger"
    args.mnemonic = "Fl"
    Unit.init(self,args)
end

function Flanger:onLoadGraph(pUnit,channelCount)

    local s2m = channelCount > 1 and self:createObject("StereoToMono","s2m") or nil 
    local lfo1 = self:createObject("SineOscillator","lfo1")
    local lfo1f0 = self:createObject("ConstantOffset","lfo1f0")
    local lfo1f0Control = self:createObject("ParameterAdapter","lfo1f0Control")
    local lfo1Gain = self:createObject("GainBias","lfo1Gain")
    local lfo1Offset = self:createObject("ConstantOffset","lfo1Offset")
    local delay1 = self:createObject("Delay","delay1",1)
    local delay1time = self:createObject("ConstantOffset","delay1time")
    local delay1adapter = self:createObject("ParameterAdapter","delay1adapter")
    local dryMix = self:createObject("Sum","dryMix")
    local amtVCA = self:createObject("Multiply","amtVCA")
    local amtVCALevel = self:createObject("ConstantOffset","amtVCALevel")
    local amtVCALevelControl = self:createObject("ParameterAdapter","amtVCALevelControl")
    local fdbk = self:createObject("GainBias","fdbk")
    local wetVCA = self:createObject("Multiply","wetVCA")
    local dryVCA = self:createObject("Multiply","dryVCA")
    local wet = self:createObject("GainBias","wet")
    local one = self:createObject("ConstantOffset","one")
    local negone = self:createObject("ConstantOffset","negone")
    local invert = self:createObject("Multiply","invert")
    local drySum = self:createObject("Sum","drySum")


    delay1time:hardSet("Offset",0.0025)
    delay1adapter:hardSet("Gain",0.0025)
    -- delay1adapter:hardSet("Offset",0.0025)
    delay1:allocateTimeUpTo(0.1)
    one:hardSet("Offset",1.0)
    negone:hardSet("Offset",-1.0)
    lfo1Gain:hardSet("Gain",0.25)
    lfo1Offset:hardSet("Offset",0.5)




    tie(lfo1f0,"Offset",lfo1f0Control,"Out")
    tie(amtVCALevel,"Offset",amtVCALevelControl,"Out")
    tie(delay1,"Left Delay",delay1adapter,"Out")

    self:addBranch("amt","Amt",amtVCALevelControl,"In")
    self:addBranch("rate","Rate",lfo1f0Control,"In")
    self:addBranch("feedback","Feedback",fdbk,"In")
    self:addBranch("wet","Wet",wet,"In")
    
    connect(lfo1f0,"Out",lfo1,"Fundamental")
    connect(lfo1,"Out",lfo1Gain,"In")
    connect(lfo1Gain,"Out",lfo1Offset,"In")
    connect(lfo1Offset,"Out",amtVCA,"Left")
    connect(amtVCALevel,"Out",amtVCA,"Right")
    connect(amtVCA,"Out",delay1time,"In")
    connect(delay1time,"Out",delay1adapter,"In")
    connect(fdbk,"Out",delay1,"Feedback")

    if channelCount > 1 then
      connect(pUnit,"In1",s2m,"Left In")
      connect(pUnit,"In2",s2m,"Right In")
      connect(s2m,"Out",delay1,"Left In")
      connect(delay1,"Left Out",wetVCA,"Left")
      connect(wet,"Out",wetVCA,"Right")
      connect(wetVCA,"Out",dryMix,"Left")
      connect(pUnit,"In1",dryVCA,"Left")
      connect(one,"Out",drySum,"Left")
      connect(wet,"Out",invert,"Left")
      connect(negone,"Out",invert,"Right")
      connect(invert,"Out",drySum,"Right")
      connect(drySum,"Out",dryVCA,"Right")
      connect(dryVCA,"Out",dryMix,"Right")
      connect(dryMix,"Out",pUnit,"Out1")
      connect(dryMix,"Out",pUnit,"Out2")
    else 
      connect(pUnit,"In1",delay1,"Left In")
      connect(delay1,"Left Out",wetVCA,"Left")
      connect(wet,"Out",wetVCA,"Right")
      connect(wetVCA,"Out",dryMix,"Left")
      connect(pUnit,"In1",dryVCA,"Left")
      connect(one,"Out",drySum,"Left")
      connect(wet,"Out",invert,"Left")
      connect(negone,"Out",invert,"Right")
      connect(invert,"Out",drySum,"Right")
      connect(drySum,"Out",dryVCA,"Right")
      connect(dryVCA,"Out",dryMix,"Right")
      connect(dryMix,"Out",pUnit,"Out1")
    end


end



local inputSelect = "left"

local menu = {
  "optionsHeader",
  "routing",

  "infoHeader",
  "rename",
  "load",
  "save",
}

function Flanger:onLoadMenu(objects,controls)

  if objects.s2m then

    controls.optionsHeader = MenuHeader {
      description = "Input Routing Options"
    }

    controls.routing = ModeSelect {
      description = "Stereo-to-Mono Routing",
      option = objects.s2m:getOption("Routing"),
      choices = {"left","sum","right"},
      descriptionWidth = 2,
      muteOnChange = true
    }
  end


  return menu
end

local views = {
  expanded = {"amt","rate","fdbk", "wet"},
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
  
  local amtMap = linMap(0,1.0,100)
  local rateMap = linMap(0.0,20.0,100)


function Flanger:onLoadViews(objects,controls)

      controls.amt = GainBias {
        button = "depth",
        description = "Depth",
        branch = self:getBranch("Amt"),
        gainbias = objects.amtVCALevelControl,
        range = objects.amtVCALevelControl,
        biasMap = amtMap,
        biasUnits = app.unitNone,
        initialBias = 0.8
      }    

      controls.rate = GainBias {
        button = "rate",
        description = "Rate",
        branch = self:getBranch("Rate"),
        gainbias = objects.lfo1f0Control,
        range = objects.lfo1f0Control,
        biasMap = rateMap,
        biasUnits = app.unitHertz,
        initialBias = 2.0
      }    

      controls.fdbk = GainBias {
        button = "fdbk",
        description = "Feedback",
        branch = self:getBranch("Feedback"),
        gainbias = objects.fdbk,
        range = objects.fdbk,
        biasMap = amtMap,
        biasUnits = app.unitNone,
        initialBias = 0.9
      }    

      controls.wet = GainBias {
        button = "wet",
        description = "Wet/dry Mix",
        branch = self:getBranch("Wet"),
        gainbias = objects.wet,
        range = objects.wet,
        biasMap = amtMap,
        biasUnits = app.unitNone,
        initialBias = 0.5
      }   

  return views
end



return Flanger
