local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

--- safely wait for the player and their data to be loaded ---
if not game:IsLoaded() then
	repeat
		task.wait()
	until game:IsLoaded()
end
local LoadingStatus = player:WaitForChild("LoadingStatus")
if LoadingStatus.Value < 1 then
	repeat
		task.wait()
	until LoadingStatus.Value > 0
end









local CoffeeRemotes = require(RS:WaitForChild("CoffeeRemotesClient"))
local GetDIIPModule = script.GetDIIP
local GetDIIP = require(GetDIIPModule)
local CoffeeObjects = require(GetDIIPModule.CoffeeObjects) -- https://github.com/Coffilhg/Useful-Modules/tree/CoffeeObjects

local TestRemote = CoffeeRemotes.RemoteEvent.new("Test")

local playerData = GetDIIP.GetPlayerData() :: CoffeeObjects.CoffeeFolder
print("LocalPlayer.Data:", playerData) -- {}


print("LocalPlayer.Data.Test3:", playerData.Test3:Await())
-- Test3 was already loaded with :Await(), so this must work
-- this won't work if we remove the safe loading or Await for
-- a value that player data doesnt contain
playerData.Test3.ChildAdded:Connect(function(key, value)
	print("Client got a ChildAdded!", key, value)
end)

-- Access some nested value
local NestedValue = playerData.Test1.Test2.Tst:Await() :: CoffeeObjects.CoffeeBaseValue
print(`LocalPlayer.Data.{table.concat(NestedValue:GetPath(), ".")}.Value = {NestedValue.Value}`)
NestedValue.Changed:Connect(function(oldValue, newValue)
	print(`LocalPlayer.Data.{table.concat(NestedValue:GetPath(), ".")} Value Changed: {oldValue} -> {newValue}`)
end)



-- press C to see debug
local n = 0
local UIS = game:GetService("UserInputService")
UIS.InputEnded:Connect(function(input, isProcessed)
	if isProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.C then
		--print("LocalPlayer.Data:", playerData)
		--print("Updates received during last second:", GetDIIP.Counter)
		--print("LocalPlayer.Data.Test3:", playerData.Test3)
		TestRemote:FireServer()
		n+=1
		if n % 20 == 0 then
			NestedValue = playerData.Test1.Test2.Tst:Await() :: CoffeeObjects.CoffeeBaseValue
			print(`LocalPlayer.Data.{table.concat(NestedValue:GetPath(), ".")}.Value = {NestedValue.Value}`)
			NestedValue.Changed:Connect(function(oldValue, newValue)
				print(`LocalPlayer.Data.{table.concat(NestedValue:GetPath(), ".")} Value Changed: {oldValue} -> {newValue}`)
			end)
			print("CONNECTED NESTED")
		elseif n % 10 == 0 then
			print("DISCONNECTED NESTED")
			NestedValue:Destroy()
		end
	end
end)

print("Dependency load success")