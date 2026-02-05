-- GetDIIP is a short for
-- Get Data Instances Inside Player

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local CoffeeRemotesClient = RS:WaitForChild("CoffeeRemotesClient")
local CoffeeRemotes = require(CoffeeRemotesClient)
local CoffeeObjects = require(script.CoffeeObjects)
local CoffeeBaseValue = CoffeeObjects.CoffeeBaseValue
local CoffeeFolder = CoffeeObjects.CoffeeFolder

local Counter = require(RS:WaitForChild("Counter")).new():setInterval(1)

--- Waiting For Server to create these
local DataUpdatePublicFolderValueRemote = RS:WaitForChild("DataUpdatePublicFolderValueRemote")
local UnreliableDataUpdatePublicFolderValueRemote = RS:WaitForChild("UnreliableDataUpdatePublicFolderValueRemote")

local PlayersDataCache = {}



local module = {}

-- player defaults to game.Players.LocalPlayer if nil
function module.GetPlayerData(player : Player?)
	if not player then
		player = Players.LocalPlayer
	end
	
	local UID = player.UserId
	
	local dataCache = PlayersDataCache[UID]
	if dataCache then
		return dataCache
	end
	
	local dataRoot = CoffeeFolder.new(nil, UID)
	PlayersDataCache[UID] = dataRoot
	
	return dataRoot
end

local GetFolderReplicatedCDNs = CoffeeRemotes.RemoteFunction.new("GetFolderReplicatedCDNs")
local LoadPublicFolderValues = CoffeeRemotes.RemoteFunction.new("LoadPublicFolderValuePerPath")

local success, FolderReplicatedCDNs = GetFolderReplicatedCDNs:InvokeServer()
if not success then
	repeat
		task.wait()
		success, FolderReplicatedCDNs = GetFolderReplicatedCDNs:InvokeServer()
	until success
end

local ValueInstanceClassNamePerType = {
	string = "StringValue",
	number = "NumberValue",
	boolean = "BoolValue",
	typeof = {
		BrickColor = "BrickColorValue",
		CFrame = "CFrameValue",
		Color3 = "Color3Value",
		Vector3 = "Vector3Value"
	},
}

local PublicFolderValues = {}

GetPathArrangements = CoffeeRemotes.RemoteFunction.new("GetPathArrangements")
	local PathArrangements = CoffeeObjects:GetPathArrangements()

local LoadsPerPathIndex = {}
local function ApplyUpdate(UID, path, newValue)
	Counter()
	
	local publicFolderValues = PublicFolderValues[UID]
	if not publicFolderValues then
		return
	end

	local valueInstanceUpdateCallback = publicFolderValues[path]
	if type(valueInstanceUpdateCallback) ~= "function" then
		return
	end

	valueInstanceUpdateCallback(newValue)
end
local function YieldRemoteFunctionUntilSuccess(RemoteFunction : CoffeeRemotes.RemoteFunctionType, ...)
	local success, result = RemoteFunction:InvokeServer(...)
	if not success then
		repeat
			task.wait()
			success, result = RemoteFunction:InvokeServer(...)
		until success
	end
	return result
end
function LoadArrangement(index : number, UID, newValue)
	if PathArrangements[index] then
		return
	end
	
	
	
	if not LoadsPerPathIndex[index] then
		LoadsPerPathIndex[index] = {}
		LoadsPerPathIndex[index][UID] = newValue
	else
		LoadsPerPathIndex[index][UID] = newValue
		return -- already Yielding
	end
	
	
	
	print("Loading PathArrangement for", index)
	local path = YieldRemoteFunctionUntilSuccess(GetPathArrangements, index)
	PathArrangements[index] = path
	print(`PathArrangements[{index}]:`, PathArrangements[index])
	
	for uid, value in pairs(LoadsPerPathIndex[index]) do
		ApplyUpdate(uid, path, value)
	end
	LoadsPerPathIndex[index] = nil
	
	return PathArrangements[index]
end
local function DUF(UID : number, pathIndex : number, newValue)
	--print("DUF", UID, pathIndex, newValue)
	local path = PathArrangements[pathIndex]
	if not path then
		LoadArrangement(pathIndex, UID, newValue)
		return
	end
	
	ApplyUpdate(UID, path, newValue)
end
DataUpdatePublicFolderValueRemote.OnClientEvent:Connect(DUF)
UnreliableDataUpdatePublicFolderValueRemote.OnClientEvent:Connect(DUF)

local function updateValueInstance(value, parent, valueInstance, name, UID)
	--print(`Updating "{name}" for Player~{UID}`)
	
	if valueInstance then
		local valueInstanceClassName = "NumberValue"
		if value then
			valueInstanceClassName = ValueInstanceClassNamePerType[type(value)]
			if not valueInstanceClassName then
				valueInstanceClassName = ValueInstanceClassNamePerType["typeof"][typeof(value)]
			end
			if not valueInstanceClassName then
				warn(`Can't apply a new value ({typeof(value)}: {value}) to Player_{UID}.{parent.Name}.{valueInstance.Name}`)
				return
			end
		end
		
		if valueInstanceClassName ~= valueInstance.ClassName then
			valueInstance:Destroy()
			valueInstance = Instance.new(valueInstanceClassName, parent)
			valueInstance.Name = `{name}`
		end
		
		valueInstance.Value = value
		
		return valueInstance
	end
	
	
	if not value then
		valueInstance = Instance.new("NumberValue", parent)
		valueInstance.Name = `{name}`
	else
		local valueInstanceClassName = ValueInstanceClassNamePerType[type(value)]
		if not valueInstanceClassName then
			valueInstanceClassName = ValueInstanceClassNamePerType["typeof"][typeof(value)]
		end
		if not valueInstanceClassName then
			warn(`Can't apply a value ({typeof(value)}: {value}) to Player_{UID}.{parent.Name}.{valueInstance.Name}`)
			return 
		end
		
		valueInstance = Instance.new(valueInstanceClassName, parent)
		valueInstance.Value = value
		valueInstance.Name = `{name}`
	end
	
	return valueInstance
end

function PlayerAdded(player : Player)
	local UID = player.UserId
	local folderValues = {}
	PublicFolderValues[UID] = folderValues
	
	local loadSuccess, publicFolderValues = LoadPublicFolderValues:InvokeServer(UID)
	if not loadSuccess then
		repeat
			task.wait(0.3)
			loadSuccess, publicFolderValues = LoadPublicFolderValues:InvokeServer(UID)
		until loadSuccess
	end
	
	for folderName, folderCDNs in pairs(FolderReplicatedCDNs) do
		local folder = Instance.new("Folder", player)
		folder.Name = folderName

		for _, CDNInfo in ipairs(folderCDNs) do
			local path = CDNInfo["CDN"]

			if not path then
				continue
			end
			
			local value = publicFolderValues[path]
			local name = CDNInfo["DisplayName"] or path
			local valueInstance = updateValueInstance(value, folder, nil, name, UID)
			
			folderValues[path] = function(newValue)
				valueInstance = updateValueInstance(newValue, folder, valueInstance, name, UID)
			end
		end
	end
end
for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end
Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player : Player)
	local UID = player.UserId
	
	if UID == Players.LocalPlayer.UserId then
		return
	end
	
	if PlayersDataCache[UID] then
		PlayersDataCache[UID]:Destroy()
	end
	
	PlayersDataCache[UID] = nil
end)

module.Counter = Counter

return module