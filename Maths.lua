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
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Maths = Class{}
Maths:include(Unit)

function Maths:init(args)
  args.title = "Maths"
  args.mnemonic = "Ma"
  Unit.init(self,args)
end


function Maths:onLoadGraph(pUnit)
  -- create objects

  local a = self:createObject("ConstantGain","a")
  local b = self:createObject("ConstantGain","b")
  local sum = self:createObject("Sum","sum")
  a:hardSet("Gain",1.0)
  b:hardSet("Gain",1.0)
  a:setClampInDecibels(-59.9)
  b:setClampInDecibels(-59.9)
  self:addBranch("inA","InA", a, "In")
  self:addBranch("inB","InB", b, "In")

  local negOne = self:createObject("Constant","negOne")
  negOne:hardSet("Value",-1.0)
  local one = self:createObject("Constant","one")
  one:hardSet("Value",1.0)

  local invert1 = self:createObject("Multiply","invert1")
  local invert2 = self:createObject("Multiply","invert2")
  local invert2C = self:createObject("Constant","invert2C")
  invert2C:hardSet("Value",-1.0)
  local invert3 = self:createObject("Multiply","invert3")
  local invert3C = self:createObject("Constant","invert3C")
  invert3C:hardSet("Value",1.0)


  local compare = self:createObject("Comparator","compare")
  compare:setGateMode()
  compare:hardSet("Hysteresis",0.0)
  compare:hardSet("Threshold",0.0)
  
  local vcaA = self:createObject("Multiply","vcaA")
  local vcaB = self:createObject("Multiply","vcaB")
  local selectSum1 = self:createObject("Sum","selectSum1")
  local selectSum1V = self:createObject("Constant","selectSum1V")
  local selectSum2 = self:createObject("Sum","selectSum2")
  local selectSum2V = self:createObject("Constant","selectSum2V")
  selectSum1V:hardSet("Value",0.0)
  selectSum2V:hardSet("Value",1.0)
  
  local minmaxMix = self:createObject("Sum","minmaxMix")

  local meanSum = self:createObject("Sum","meanSum")
  local meanVCA = self:createObject("Multiply","meanVCA")
  local meanVCAC = self:createObject("Constant","meanVCAC")
  meanVCAC:hardSet("Value",0.5)

  local selectMinMax = self:createObject("Multiply","selectMinMax")
  local selectMean = self:createObject("Multiply","selectMean")
  local selectMinMaxC = self:createObject("Constant","selectMinMaxC")
  local selectMeanC = self:createObject("Constant","selectMeanC")
  selectMinMaxC:hardSet("Value",1.0)
  selectMeanC:hardSet("Value",0.0)
  local finalMix = self:createObject("Sum","finalMix")

  -- mix/max
  connect(a,"Out",sum,"Left")
  connect(b,"Out",invert1,"Left")
  connect(negOne,"Out",invert1,"Right")
  connect(invert1,"Out",sum,"Right")
  connect(sum,"Out",compare,"In")
  connect(compare,"Out",invert3,"Left")
  connect(invert3C,"Out",invert3,"Right")
  connect(invert3,"Out",selectSum1,"Left")
  connect(selectSum1V,"Out",selectSum1,"Right")
  connect(a,"Out",vcaA,"Left")
  connect(selectSum1,"Out",vcaA,"Right")
  connect(compare,"Out",invert2,"Left")
  connect(invert2C,"Out",invert2,"Right")
  connect(invert2,"Out",selectSum2,"Left")
  connect(selectSum2V,"Out",selectSum2,"Right")
  connect(b,"Out",vcaB,"Left")
  connect(selectSum2,"Out",vcaB,"Right")
  connect(vcaA,"Out", minmaxMix,"Left")
  connect(vcaB,"Out",minmaxMix,"Right")
  connect(minmaxMix,"Out",selectMinMax,"Left")
  connect(selectMinMaxC,"Out",selectMinMax,"Right")
  connect(selectMinMax,"Out",finalMix,"Left")

  -- mean
  connect(a,"Out",meanSum,"Left")
  connect(b,"Out",meanSum,"Right")
  connect(meanSum,"Out",meanVCA,"Left")
  connect(meanVCAC,"Out",meanVCA,"Right")
  connect(meanVCA,"Out",selectMean,"Left")
  connect(selectMeanC,"Out",selectMean,"Right")
  connect(selectMean,"Out",finalMix,"Right")

  connect(finalMix,"Out",pUnit,"Out1")



end

local views = {
  expanded = {"a","b"},
  collapsed = {},
  input = {}
}


function Maths:onLoadViews(objects,controls)
  
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

      self:addToMuteGroup(controls.a)
      self:addToMuteGroup(controls.b)


  return views
end

local menu = {
  "setHeader",
  "max",
  "min",
  "mean",
  "infoHeader",
  "rename",
  "load",
  "save"
}

local op = "MAX"

function Maths:onLoadMenu(objects,controls)

  controls.setHeader = MenuHeader {
    description = string.format("Current op is: %s.",op)
  }

  controls.max = Task {
    description = "MAX",
    task = function()  
      objects.selectSum1V:hardSet("Value",0.0)
      objects.selectSum2V:hardSet("Value",1.0)
      objects.invert2C:hardSet("Value",-1.0)
      objects.invert3C:hardSet("Value",1.0)
      objects.selectMinMaxC:hardSet("Value",1.0)
      objects.selectMeanC:hardSet("Value",0.0)
      op = "MAX"
    end
  }

  controls.min = Task {
    description = "MIN",
    task = function()  
      objects.selectSum1V:hardSet("Value",1.0)
      objects.selectSum2V:hardSet("Value",0.0)
      objects.invert2C:hardSet("Value",1.0)
      objects.invert3C:hardSet("Value",-1.0)
      objects.selectMinMaxC:hardSet("Value",1.0)
      objects.selectMeanC:hardSet("Value",0.0)
      op = "MIN"
    end
  }

  controls.mean = Task {
    description = "MEAN",
    task = function()  
      objects.selectMinMaxC:hardSet("Value",0.0)
      objects.selectMeanC:hardSet("Value",1.0)
      op="MEAN"
    end
  }

  return menu
end
return Maths
