-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
-- local ModeSelect = require "Unit.MenuControl.OptionControl"
local MenuHeader = require "Unit.MenuControl.Header"
local Task = require "Unit.MenuControl.Task"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
-- local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local VoltageBank = Class{}
VoltageBank:include(Unit)

function VoltageBank:init(args)
  args.title = "Voltage Bank"
  args.mnemonic = "VB"
  Unit.init(self,args)
end

function VoltageBank:onLoadGraph(pUnit, channelCount)
  -- create objects
 
      -- Create network objects
      local localVars = {}
      local numSlots = 8

      -- define the different objects to be mass created
      local objectList = {
        sh = { "TrackAndHold" },
        shOut = { "Multiply" },
        shTrack = { "Multiply" },
        shMix = { "Sum" },
        bump  = { "BumpMap" },
       }
  
      for k, v in pairs(objectList) do
        for i = 1, numSlots do
          local dynamicVar = k .. i
          local dynamicDSPUnit = v[1]
          localVars[dynamicVar] = self:createObject(dynamicDSPUnit,dynamicVar)
        end
      end

      local index = self:createObject("GainBias","index")
      index:hardSet("Gain",1.0)
      local indexRange = self:createObject("MinMax","indexRange")
      local trig = self:createObject("Comparator","trig")
      local divIndex = self:createObject("ConstantGain","divIndex")
      divIndex:hardSet("Gain",1/numSlots)
      self:addBranch("trig","Trigger",trig,"In")
      self:addBranch("index","Index",index,"In")

      local bumpMapWidth = 1 / numSlots
      local bumpMapOffset = bumpMapWidth / 2

      local bumpOffset = self:createObject("ConstantOffset","bumpOffset")
      bumpOffset:hardSet("Offset",-bumpMapOffset)

      local inToOutVCA = self:createObject("Multiply","inToOutVCA")
      local inToOutVCAConst = self:createObject("Constant","inToOutVCAConst")
      inToOutVCAConst:hardSet("Value",0.0)
      local indexToOutVCA = self:createObject("Multiply","indexToOutVCA")
      local indexToOutVCAConst = self:createObject("Constant","indexToOutVCAConst")
      indexToOutVCAConst:hardSet("Value",1.0)
      local outputMixer = self:createObject("Sum","outputMixer")

      -- set bump map properties
      for i = 1, numSlots do
        localVars["bump" .. i]:hardSet("Height",1.0)
        localVars["bump" .. i]:hardSet("Fade",0.0)
        localVars["bump" .. i]:hardSet("Width",bumpMapWidth)
        localVars["bump" .. i]:hardSet("Center",(bumpMapWidth*i)-bumpMapOffset)
      end

      -- connect objects
      connect(index,"Out",indexRange,"In")
      connect(index,"Out",divIndex,"In")
      connect(divIndex,"Out",bumpOffset,"In")
      connect(localVars["shOut1"],"Out",localVars["shMix1"],"Left")
      connect(localVars["shOut2"],"Out",localVars["shMix1"],"Right")

      for i = 1, numSlots do
        connect(bumpOffset,"Out",localVars["bump" .. i],"In")
        connect(pUnit,"In1",localVars["sh" .. i],"In")
        connect(trig,"Out",localVars["shTrack" .. i],"Left")
        connect(localVars["bump" .. i],"Out",localVars["shTrack" .. i],"Right")
        connect(localVars["shTrack" .. i],"Out",localVars["sh" .. i],"Track")
        connect(localVars["sh" .. i],"Out",localVars["shOut" .. i],"Left")
        connect(localVars["bump" .. i],"Out",localVars["shOut" .. i],"Right")
        if i < numSlots - 1 then
            connect(localVars["shMix" .. i],"Out",localVars["shMix" .. i + 1],"Left")
            connect(localVars["shOut" .. i + 2],"Out",localVars["shMix" .. i + 1],"Right")
        end
      end

    connect(localVars["shMix" .. numSlots-1],"Out",indexToOutVCA,"Left")
    connect(indexToOutVCAConst,"Out",indexToOutVCA,"Right")
    connect(indexToOutVCA,"Out",outputMixer,"Left")
    connect(pUnit,"In1",inToOutVCA,"Left")
    connect(inToOutVCAConst,"Out",inToOutVCA,"Right")
    connect(inToOutVCA,"Out",outputMixer,"Right")
    connect(outputMixer,"Out",pUnit,"Out1")

end

local menu = {
    "setHeader",
    "index",
    "input",
    "sum",
    "infoHeader",
    "rename",
    "load",
    "save"
  }
  
  local op = "index"
  
  function VoltageBank:onLoadMenu(objects,controls)
  
    controls.setHeader = MenuHeader {
      description = string.format("Output signal: %s.",op)
    }
  
    controls.index = Task {
      description = "index",
      task = function()  
        objects.inToOutVCAConst:hardSet("Value",0.0)
        objects.indexToOutVCAConst:hardSet("Value",1.0)
        op = "index"
      end
    }

    controls.input = Task {
        description = "input",
        task = function()  
          objects.inToOutVCAConst:hardSet("Value",1.0)
          objects.indexToOutVCAConst:hardSet("Value",0.0)
          op = "input"
        end
      }

      controls.sum = Task {
        description = "sum",
        task = function()  
          objects.inToOutVCAConst:hardSet("Value",1.0)
          objects.indexToOutVCAConst:hardSet("Value",1.0)
          op = "sum"
        end
      }
    return menu
end


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

local indexMap = intMap(1,8)  -- adjust max param for numSlots

local views = {
  expanded = {"trigger","index"},
  collapsed = {},
}

function VoltageBank:onLoadViews(objects,controls)

    controls.trigger = Comparator {
        button = "trig",
        branch = self:getBranch("Trigger"),
        description = "Trigger",
        edge = objects.trig,
      }
    
      controls.index = GainBias {
        button = "index",
        description = "Bank Slot",
        branch = self:getBranch("Index"),
        gainbias = objects.index,
        range = objects.indexRange,
        biasMap = indexMap,
        biasUnits = app.unitInteger,
        gainMap = indexMap,
        initialBias = 1,
      }

  return views
end

return VoltageBank
