-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local ModeSelect = require "Unit.ViewControl.OptionControl"
local InputComparator = require "Unit.ViewControl.InputComparator"
local OutputScope = require "Unit.ViewControl.OutputScope"
local GainBias = require "Unit.ViewControl.GainBias"
local BranchMeter = require "Unit.ViewControl.BranchMeter"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Logics = Class{}
Logics:include(Unit)

function Logics:init(args)
  args.title = "Logics"
  args.mnemonic = "Lg"
  Unit.init(self,args)
end


function Logics:onLoadGraph(pUnit,channelCount)
  
  -- create input circuit objects
  local a = self:createObject("ConstantGain","a")
  local b = self:createObject("ConstantGain","b")
  local sum = self:createObject("Sum","sum")
  a:hardSet("Gain",1.0)
  b:hardSet("Gain",1.0)
  a:setClampInDecibels(-59.9)
  b:setClampInDecibels(-59.9)
  self:addBranch("inA","InA", a, "In")
  self:addBranch("inB","InB", b, "In")
  local compA = self:createObject("Comparator","compA")
  local compB = self:createObject("Comparator","compB")
  compA:hardSet("Hysteresis",0.0)
  compB:hardSet("Hysteresis",0.0)
  compA:setGateMode()
  compB:setGateMode()
  local modA = self:createObject("Multiply","modA")
  local modB = self:createObject("Multiply","modB")

  -- create control objects
  local threshold = self:createObject("ParameterAdapter","threshold")
  local thresholdOutlet = self:createObject("Constant","thresholdOutlet")
  tie(compA,"Threshold",threshold,"Out")
  tie(compB,"Threshold",threshold,"Out")
  tie(thresholdOutlet,"Value",threshold,"Out")
  self:addBranch("threshold","Threshold",threshold,"In")

  local truth = self:createObject("GainBias","truth")
  local falsth = self:createObject("GainBias","falsth")
  local truthRange = self:createObject("MinMax","truthRange")
  local falsthRange = self:createObject("MinMax","falsthRange")
  
  self:addBranch("true","True",truth,"In")
  self:addBranch("false","False",falsth,"In")

  -- create AND logic objects
  local ANDSum1 = self:createObject("Sum","ANDSum1")
  local ANDSum2 = self:createObject("Sum","ANDSum2")
  local compAND = self:createObject("Comparator","compAND")
  compAND:setGateMode()
  compAND:hardSet("Hysteresis",0.0)
  local ANDThreholdAdapter = self:createObject("ParameterAdapter","ANDThreholdAdapter")
  ANDThreholdAdapter:hardSet("Gain",1.0)

  -- create OR logic objects
  local ORSum = self:createObject("Sum","ORSum")
  local compOR = self:createObject("Comparator","compOR")
  compOR:setGateMode()
  compOR:hardSet("Hysteresis",0.0)

  -- create XOR logic objects
  local compXORA = self:createObject("Comparator","compXORA")
  local compXORB = self:createObject("Comparator","compXORB")
  local XORSum1 = self:createObject("Sum","XORSum1")
  local XORSum2 = self:createObject("Sum","XORSum2")
  local XORSum3 = self:createObject("Sum","XORSum3")
  local XORMult1 = self:createObject("Multiply","XORMult1")
  local XORMult2 = self:createObject("Multiply","XORMult2")
  local XORConst = self:createObject("Constant","XORConst")
  XORConst:hardSet("Value",-1.0)
  local compXOR = self:createObject("Comparator","compXOR")
  compXOR:setGateMode()
  compXOR:hardSet("Hysteresis",0.0)
  compXORA:setGateMode()
  compXORA:hardSet("Hysteresis",0.0)
  compXORB:setGateMode()
  compXORB:hardSet("Hysteresis",0.0)

  -- create selection circuit objects
  local selectMult1 = self:createObject("Multiply","selectMult1")
  local selectMult2 = self:createObject("Multiply","selectMult2")
  local selectMult3 = self:createObject("Multiply","selectMult3")
  local selectMult4 = self:createObject("Multiply","selectMult4")
  local ANDSelectorConst = self:createObject("Constant","ANDSelectorConst")
  local ORSelectorConst = self:createObject("Constant","ORSelectorConst")
  local XORSelectorConst = self:createObject("Constant","XORSelectorConst")
  local NOTInverterConst = self:createObject("Constant","NOTInverterConst")
  ANDSelectorConst:hardSet("Value",1.0)
  ORSelectorConst:hardSet("Value",0.0)
  XORSelectorConst:hardSet("Value",0.0)
  NOTInverterConst:hardSet("Value",-1.0)
  local selectMix1 = self:createObject("Sum","selectMix1")
  local selectMix2 = self:createObject("Sum","selectMix2")
  local selectMix3 = self:createObject("Sum","selectMix3")
  local NOTOffsetConst = self:createObject("Constant","NOTOffsetConst")
  NOTOffsetConst:hardSet("Value",0.0)

  -- create output objects
  local outMult1 = self:createObject("Multiply","outMult1")
  local outMult2 = self:createObject("Multiply","outMult2")
  local outMult3 = self:createObject("Multiply","outMult3")
  local outSum1 = self:createObject("Sum","outSum1")
  local outSum2 = self:createObject("Sum","outSum2")
  local negOne = self:createObject("Constant","negOne")
  local one = self:createObject("Constant","one")
  negOne:hardSet("Value",-1.0)
  one:hardSet("Value",1.0)

  -- wire input circuit
  connect(a,"Out",compA,"In")
  connect(b,"Out",compB,"In")
  connect(compA,"Out",modA,"Left")
  connect(compB,"Out",modB,"Left")
  connect(thresholdOutlet,"Out",modA,"Right")
  connect(thresholdOutlet,"Out",modB,"Right")

  -- wire AND logic
  connect(modA,"Out",ANDSum1,"Left")
  connect(modB,"Out",ANDSum1,"Right")
  connect(thresholdOutlet,"Out",ANDSum2,"Left")
  connect(thresholdOutlet,"Out",ANDSum2,"Right")
  connect(ANDSum1,"Out",compAND,"In")
  tie(compAND,"Threshold",ANDThreholdAdapter,"Out")
  connect(ANDSum2,"Out",ANDThreholdAdapter,"In")
  -- compAND to selection circuit input

  --wire OR logic
  connect(modA,"Out",ORSum,"Left")
  connect(modB,"Out",ORSum,"Right")
  connect(ORSum,"Out",compOR,"In")
  tie(compOR,"Threshold",threshold,"Out")
  -- compOR to selection circuit input


  --wire XOR logic
  connect(compOR,"Out",XORSum1,"Left")
  connect(compAND,"Out",XORMult1,"Left")
  connect(XORConst,"Out",XORMult1,"Right")
  connect(XORMult1,"Out",XORSum1,"Right")
  -- XORSum1 to selection circuit

  --wire selection circuit
  connect(compAND,"Out",selectMult1,"Left")
  connect(ANDSelectorConst,"Out",selectMult1,"Right")
  connect(compOR,"Out",selectMult2,"Left")
  connect(ORSelectorConst,"Out",selectMult2,"Right")
  connect(XORSum1,"Out",selectMult3,"Left")
  connect(XORSelectorConst,"Out",selectMult3,"Right")
  connect(selectMult1,"Out",selectMix1,"Left")
  connect(selectMult2,"Out",selectMix1,"Right")
  connect(selectMix1,"Out",selectMix2,"Left")
  connect(selectMult3,"Out",selectMix2,"Right")
  connect(selectMix2,"Out",selectMult4,"Left")
  connect(NOTInverterConst,"Out",selectMult4,"Right")
  connect(selectMult4,"Out",selectMix3,"Left")
  connect(NOTOffsetConst,"Out",selectMix3,"Right")
  --selectMix3 to output circuit

  --connect output circuit
  connect(truth,"Out",outMult1,"Left")
  connect(falsth,"Out",outMult2,"Left")
  connect(truth,"Out",truthRange,"In")
  connect(falsth,"Out",falsthRange,"In")
  connect(selectMix3,"Out",outMult3,"Left")
  connect(selectMix3,"Out",outMult1,"Right")
  connect(negOne,"Out",outMult3,"Right")
  connect(outMult3,"Out",outSum1,"Left")
  connect(one,"Out",outSum1,"Right")
  connect(outSum1,"Out",outMult2,"Right")
  connect(outMult1,"Out",outSum2,"Left")
  connect(outMult2,"Out",outSum2,"Right")
  connect(outSum2,"Out",pUnit,"Out1")
  -- connect(XORSum1,"Out",pUnit,"Out1")

  if channelCount > 1 then
    connect(outSum2,"Out",pUnit,"Out2")
end




end

local views = {
  expanded = {"a","b","threhold","truth","falseth"},
  collapsed = {},
  input = {}
}


function Logics:onLoadViews(objects,controls)
  
    controls.a = BranchMeter {
        button = "a",
        branch = self:getBranch("InA"),
        faderParam = objects.a:getParameter("Gain")
      }

      controls.b = BranchMeter {
        button = "b",
        branch = self:getBranch("InB"),
        faderParam = objects.b:getParameter("Gain")
      }

      controls.threhold = GainBias {
        button = "threshold",
        description = "Truth Threhold",
        branch = self:getBranch("Threshold"),
        gainbias = objects.threshold,
        range = objects.threshold,
        biasMap = Encoder.getMap("default"),
        initialBias = 0.1,
      }

      controls.truth = GainBias {
        button = "true",
        description = "True Output",
        branch = self:getBranch("True"),
        gainbias = objects.truth,
        range = objects.truthRange,
        biasMap = Encoder.getMap("default"),
        initialBias = 1.0,
      }

 
      controls.falseth = GainBias {
        button = "false",
        description = "False Output",
        branch = self:getBranch("False"),
        gainbias = objects.falsth,
        range = objects.falsthRange,
        biasMap = Encoder.getMap("default"),
        initialBias = 0.0,
      }

      self:addToMuteGroup(controls.a)
      self:addToMuteGroup(controls.b)


  return views
end

local menu = {
  "setHeader",
  "opAND",
  "opOR",
  "opXOR",
  "opNAND",
  "opNOR",
  "opXNOR",
  "infoHeader",
  "rename",
  "load",
  "save"
}

local op = "AND"

function Logics:onLoadMenu(objects,controls)

  controls.setHeader = MenuHeader {
    description = string.format("Current op is: %s.",op)
  }

  controls.opAND = Task {
    description = "AND",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",1.0)
      objects.ORSelectorConst:hardSet("Value",0.0)
      objects.XORSelectorConst:hardSet("Value",0.0)
      objects.NOTInverterConst:hardSet("Value",1.0)
      objects.NOTOffsetConst:hardSet("Value",0.0)
      op = "AND"
    end
  }

  controls.opOR = Task {
    description = "OR",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",0.0)
      objects.ORSelectorConst:hardSet("Value",1.0)
      objects.XORSelectorConst:hardSet("Value",0.0)
      objects.NOTInverterConst:hardSet("Value",1.0)
      objects.NOTOffsetConst:hardSet("Value",0.0)
      op = "OR"
    end
  }

  controls.opXOR = Task {
    description = "XOR",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",0.0)
      objects.ORSelectorConst:hardSet("Value",0.0)
      objects.XORSelectorConst:hardSet("Value",1.0)
      objects.NOTInverterConst:hardSet("Value",1.0)
      objects.NOTOffsetConst:hardSet("Value",0.0)
      op = "XOR"
    end
  }

  controls.opNAND = Task {
    description = "NAND",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",1.0)
      objects.ORSelectorConst:hardSet("Value",0.0)
      objects.XORSelectorConst:hardSet("Value",0.0)
      objects.NOTInverterConst:hardSet("Value",-1.0)
      objects.NOTOffsetConst:hardSet("Value",1.0)
      op = "NAND"
    end
  }

  controls.opNOR = Task {
    description = "NOR",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",0.0)
      objects.ORSelectorConst:hardSet("Value",1.0)
      objects.XORSelectorConst:hardSet("Value",0.0)
      objects.NOTInverterConst:hardSet("Value",-1.0)
      objects.NOTOffsetConst:hardSet("Value",1.0)
      op = "NOR"
    end
  }

  controls.opXNOR = Task {
    description = "XNOR",
    task = function()  
      objects.ANDSelectorConst:hardSet("Value",0.0)
      objects.ORSelectorConst:hardSet("Value",0.0)
      objects.XORSelectorConst:hardSet("Value",1.0)
      objects.NOTInverterConst:hardSet("Value",-1.0)
      objects.NOTOffsetConst:hardSet("Value",1.0)
      op = "XNOR"
    end
  }



  return menu
end
return Logics
