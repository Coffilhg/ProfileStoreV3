--[[
MAD STUDIO (by loleris)

-[ProfileStore]---------------------------------------

	Periodic DataStore saving solution with session locking
	
	WARNINGS FOR "Profile.Data" VALUES:
	 	! Do not create numeric tables with gaps - attempting to store such tables will result in an error.
		! Do not create mixed tables (some values indexed by number and others by a string key)
			- only numerically indexed  data will be stored.
		! Do not index tables by anything other than numbers and strings.
		! Do not reference Roblox Instances
		! Do not reference userdata (Vector3, Color3, CFrame...) - Serialize userdata before referencing
		! Do not reference functions
		
	Members:
	
		ProfileStore.IsClosing          [bool]
			-- Set to true after a game:BindToClose() trigger
			
		ProfileStore.IsCriticalState    [bool]
			-- Set to true when ProfileStore experiences too many consecutive errors
		
		ProfileStore.OnError            [Signal] (message, store_name, profile_key)
			-- Most ProfileStore errors will be caught and passed to this signal
			
		ProfileStore.OnOverwrite        [Signal] (store_name, profile_key)
			-- Triggered when a DataStore key was likely used to store data that wasn't
			a ProfileStore profile or the ProfileStore structure was invalidly manually
			altered for that DataStore key
			
		ProfileStore.OnCriticalToggle   [Signal] (is_critical)
			-- Triggered when ProfileStore experiences too many consecutive errors
		
		ProfileStore.DataStoreState     [string] ("NotReady", "NoInternet", "NoAccess", "Access")
			-- This value resembles ProfileStore's access to the DataStore; The value starts
			as "NotReady" and will eventually change to one of the other 3 possible values.
	
	Functions:
	
		ProfileStore.New(store_name, template?) --> [ProfileStore]
			store_name   [string] -- DataStore name
			template     [table] or nil -- Profiles will default to given table (hard-copy) when no data was saved previously
			
		ProfileStore.SetConstant(name, value)
			name    [string]
			value   [number]
				
	Members [ProfileStore]:
	
		ProfileStore.Mock   [ProfileStore]
			-- Reflection of ProfileStore methods, but the methods will now query a mock
			DataStore with no relation to the real DataStore
			
		ProfileStore.Name   [string]
		
	Methods [ProfileStore]:
	
		ProfileStore:StartSessionAsync(profile_key, params?) --> [Profile] or nil
			profile_key [string] -- DataStore key
			params      nil or [table]: -- Custom params; E.g. {Steal = true}
				{
					Steal = true, -- Pass this to disregard an existing session lock
					Cancel = fn() -> (boolean), -- Pass this to create a request cancel condition.
						-- If the cancel function returns true, ProfileStore will stop trying to
						-- start the session and return nil
				}
			
		ProfileStore:MessageAsync(profile_key, message) --> is_success [bool]
			profile_key [string] -- DataStore key
			message     [table] -- Data to be messaged to the profile
			
		ProfileStore:GetAsync(profile_key, version?) --> [Profile] or nil
			-- Reads a profile without starting a session - will not autosave
			profile_key   [string] -- DataStore key
			version       nil or [string] -- DataStore key version

		ProfileStore:VersionQuery(profile_key, sort_direction?, min_date?, max_date?) --> [VersionQuery]
			profile_key      [string]
			sort_direction   nil or [Enum.SortDirection]
			min_date         nil or [DateTime]
			max_date         nil or [DateTime]
			
		ProfileStore:RemoveAsync(profile_key) --> is_success [bool]
			-- Completely removes profile data from the DataStore / mock DataStore with no way to recover it.

	Methods [VersionQuery]:

		VersionQuery:NextAsync() --> [Profile] or nil -- (Yields)
			-- Returned profile is similar to profiles returned by ProfileStore:GetAsync()
		
	Members [Profile]:
	
		Profile.Data               [table]
			-- When the profile is active changes to this table are guaranteed to be saved
		Profile.LastSavedData      [table] (Read-only)
			-- Last snapshot of "Profile.Data" that has been successfully saved to the DataStore;
			Useful for proper developer product purchase receipt handling
		
		Profile.FirstSessionTime   [number] (Read-only)
			-- os.time() timestamp of the first profile session
			
		Profile.SessionLoadCount   [number] (Read-only) -- Amount of times a session was started for this profile
			
		Profile.Session            [table] (Read-only) {PlaceId = number, JobId = string} / nil
			-- Set to a table if this profile is in use by a server; nil if released

		Profile.RobloxMetaData     [table] -- Writable table that gets saved automatically and once the profile is released
		Profile.UserIds            [table] -- (Read-only) -- {user_id [number], ...} -- User ids associated with this profile

		Profile.KeyInfo            [DataStoreKeyInfo] -- Changes before OnAfterSave signal
		
		Profile.OnSave             [Signal] ()
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			
		Profile.OnLastSave         [Signal] (reason [string]: "Manual", "External", "Shutdown")
			-- Triggered right before changes to Profile.Data are saved to the DataStore
			for the last time; A reason is provided for the last save:
				- "Manual"   - Profile:EndSession() was called
				- "Shutdown" - The server that has ownership of this profile is shutting down
				- "External" - Another server has started a session for this profile
			Note that this event will not trigger for when a profile session is ended by
			another server trying to take ownership of the session - this is impossible to
			do without compromising on ProfileStore's speed.
			
		Profile.OnSessionEnd       [Signal] ()
			-- Triggered when the profile session is terminated on this server
		
		Profile.OnAfterSave        [Signal] (last_saved_data)
			-- Triggered after a successful save
			last_saved_data [table] -- Profile.LastSavedData
			
		Profile.ProfileStore       [ProfileStore] -- ProfileStore object this profile belongs to
		Profile.Key                [string] -- DataStore key
		
	Methods [Profile]:
	
		Profile:IsActive() --> [bool] -- If "true" is returned, changes to Profile.Data are guaranteed to save;
			This guarantee is only valid until code yields (e.g. task.wait() is used).
			
		Profile:Reconcile() -- Fills in missing (nil) [string_key] = [value] pairs to the Profile.Data structure
			from the "template" argument that was passed to "ProfileStore.New()"
			
		Profile:EndSession() -- Call after the server has finished working with this profile
			e.g., after the player leaves (Profile object will become inactive)

		Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)
			user_id   [number]

		Profile:RemoveUserId(user_id) -- Removes user_id association with profile (safe function)
			user_id   [number]
			
		Profile:MessageHandler(fn) -- Sets a message handler for this profile
			fn [function] (message [table], processed [function]())
			-- The handler function receives a message table and a callback function;
			The callback function is to be called when a message has been processed
			- this will discard the message from the profile message cache; If the
			callback function is not called, other message handlers will also be triggered
			with unprocessed message data.
			
		Profile:Save() -- If the profile session is still active makes an UpdateAsync call
			to the DataStore to immediately save profile data

		Profile:SetAsync() -- Forcefully saves changes to the profile; Only for profiles
			loaded with ProfileStore:GetAsync() or ProfileStore:VersionQuery()
		
--]]

local AUTO_SAVE_PERIOD = 300 -- (Seconds) Time between when changes to a profile are saved to the DataStore
local LOAD_REPEAT_PERIOD = 10 -- (Seconds) Time between successive profile reads when handling a session conflict
local FIRST_LOAD_REPEAT = 5 -- (Seconds) Time between first and second profile read when handling a session conflict
local SESSION_STEAL = 40 -- (Seconds) Time until a session conflict is resolved with the waiting server stealing the session
local ASSUME_DEAD = 630 -- (Seconds) If a profile hasn't had updates for this long, quickly assume an active session belongs to a crashed server
local START_SESSION_TIMEOUT = 120 -- (Seconds) If a session can't be started for a profile for this long, stop repeating calls to the DataStore

local CRITICAL_STATE_ERROR_COUNT = 5 -- Assume critical state if this many issues happen in a short amount of time
local CRITICAL_STATE_ERROR_EXPIRE = 120 -- (Seconds) Individual issue expiration
local CRITICAL_STATE_EXPIRE = 120 -- (Seconds) Critical state expiration

local MAX_MESSAGE_QUEUE = 1000 -- Max messages saved in a profile that were sent using "ProfileStore:MessageAsync()"

----- Dependencies -----

-- local Util = require(game.ReplicatedStorage.Shared.Util)
-- local Signal = Util.Signal

--- Signal's Source Repository: https://github.com/stravant/goodsignal/blob/master/README.md ---
--- NOTE: Signal Version used here (ProfileStoreV3) differs from one used in the original;
--- Used Signal version: latest release as of 1/1/2026
local Signal = {}

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

do
	-- The currently idle thread to run the next handler on
	local freeRunnerThread = nil

	-- Function which acquires the currently idle handler runner thread, runs the
	-- function fn on it, and then releases the thread, returning it to being the
	-- currently idle one.
	-- If there was a currently idle runner thread already, that's okay, that old
	-- one will just get thrown and eventually GCed.
	local function acquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquiredRunnerThread = freeRunnerThread
		freeRunnerThread = nil
		fn(...)
		-- The handler finished running, this runner thread is free again.
		freeRunnerThread = acquiredRunnerThread
	end

	-- Coroutine runner that we create coroutines of. The coroutine can be
	-- repeatedly resumed with functions to run followed by the argument to run
	-- them with.
	local function runEventHandlerInFreeThread()
		-- Note: We cannot use the initial set of arguments passed to
		-- runEventHandlerInFreeThread for a call to the handler, because those
		-- arguments would stay on the stack for the duration of the thread's
		-- existence, temporarily leaking references. Without access to raw bytecode
		-- there's no way for us to clear the "..." references from the stack.
		while true do
			acquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end

	-- Connection class
	local Connection = {}
	Connection.__index = Connection

	function Connection.new(signal, fn)
		return setmetatable({
			_connected = true,
			_signal = signal,
			_fn = fn,
			_next = false,
		}, Connection)
	end

	function Connection:Disconnect()
		self._connected = false

		-- Unhook the node, but DON'T clear it. That way any fire calls that are
		-- currently sitting on this node will be able to iterate forwards off of
		-- it, but any subsequent fire calls will not hit it, and it will be GCed
		-- when no more fire calls are sitting on it.
		if self._signal._handlerListHead == self then
			self._signal._handlerListHead = self._next
		else
			local prev = self._signal._handlerListHead
			while prev and prev._next ~= self do
				prev = prev._next
			end
			if prev then
				prev._next = self._next
			end
		end
	end

	-- Make Connection strict
	setmetatable(Connection, {
		__index = function(_, key)
			error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
		end,
		__newindex = function(_, key)
			error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
		end,
	})

	-- Signal class
	Signal.__index = Signal

	function Signal.new<T...>(): Signal<T...>
		return setmetatable({
			_handlerListHead = false,
		}, Signal) :: any
	end

	function Signal:Connect(fn)
		local connection = Connection.new(self, fn)
		if self._handlerListHead then
			connection._next = self._handlerListHead
			self._handlerListHead = connection
		else
			self._handlerListHead = connection
		end
		return connection
	end

	-- Disconnect all handlers. Since we use a linked list it suffices to clear the
	-- reference to the head handler.
	function Signal:DisconnectAll()
		self._handlerListHead = false
	end

	-- Signal:Fire(...) implemented by running the handler functions on the
	-- coRunnerThread, and any time the resulting thread yielded without returning
	-- to us, that means that it yielded to the Roblox scheduler and has been taken
	-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
	function Signal:Fire(...)
		local item = self._handlerListHead
		while item do
			if item._connected then
				if not freeRunnerThread then
					freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
					-- Get the freeRunnerThread to the first yield
					coroutine.resume(freeRunnerThread)
				end
				task.spawn(freeRunnerThread, item._fn, ...)
			end
			item = item._next
		end
	end

	-- Implement Signal:Wait() in terms of a temporary connection using
	-- a Signal:Connect() which disconnects itself.
	function Signal:Wait()
		local waitingCoroutine = coroutine.running()
		local cn
		cn = self:Connect(function(...)
			cn:Disconnect()
			task.spawn(waitingCoroutine, ...)
		end)
		return coroutine.yield()
	end

	-- Implement Signal:Once() in terms of a connection which disconnects
	-- itself before running the handler.
	function Signal:Once(fn)
		local cn
		cn = self:Connect(function(...)
			if cn._connected then
				cn:Disconnect()
			end
			fn(...)
		end)
		return cn
	end

	-- Make signal strict
	setmetatable(Signal, {
		__index = function(_, key)
			error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
		end,
		__newindex = function(_, key)
			error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
		end,
	})
end

--- https://github.com/Coffilhg/Useful-Modules/tree/CoffeeObjects
local CoffeeObjects = {} -- (Almost)Standalone CoffeeObjects Version for portable version (3) of ProfileStore
local CoffeeFolder = {}
local CoffeeBaseValue = {}
--- CoffeeObjects REQUIRES Signal (which is a part of the original ProfileStore too), but it's newer version ---
export type SupportedTypesList = string | number | boolean |
BrickColor | CFrame | Color3 |
ColorSequence | Content | EnumItem |
Font | NumberRange | NumberSequence |
Ray | Rect | UDim | UDim2 | Vector2 | Vector3

export type CoffeeBaseValue = {
	Value: SupportedTypesList,
	Changed: Signal,
	Destroying: Signal, -- Fired before destruction
	Destroy: (self: CoffeeBaseValue) -> (),
	GetPath: (self: CoffeeBaseValue) -> {string},
	_Value: SupportedTypesList,
	_parent: CoffeeFolder?,
	_key: string?
}

export type CoffeeFolder = {
	ChildAdded: Signal,
	ChildRemoved: Signal,
	Destroying: Signal, -- Fired before destruction
	Insert: (self: CoffeeFolder, newValue: CoffeeBaseValue | CoffeeFolder | SupportedTypesList | PrimitiveTable) -> (),
	GetPath: (self: CoffeeFolder) -> {string},
	GetChildren: (self: CoffeeFolder) -> {[string | number]: CoffeeFolder | CoffeeBaseValue},
	Destroy: (self: CoffeeFolder) -> (),
	_IsArrayORTuple: (self: CoffeeFolder) -> boolean,
	_data: {[string | number]: CoffeeFolder | CoffeeBaseValue},
	_parent: CoffeeFolder?,
	_key: string?,
	[string | number]: any 
}

export type PrimitiveTable = {
	[string | number]: CoffeeBaseValue | CoffeeFolder | SupportedTypesList | PrimitiveTable,
}

do
	--- GetPathMethod REQUIRED by CoffeeBaseValue AND CoffeeFolder ---

	-- Traverses up the hierarchy via _parent references to reconstruct the object's location.
	-- @return An array of keys (strings or numbers) representing the path from the root.
	local function GetPathMethod(self: CoffeeBaseValue | CoffeeFolder) : {[number]: string | number}
		local path = {}
		local current = self
		local parent = rawget(current, "_parent")

		while parent do
			table.insert(path, 1, rawget(current, "_key")) -- I thought using reverse in the end, but reverse doesnt exist, so doing this is ok
			current = parent
			parent = rawget(current, "_parent")
		end

		return path
	end
	--- Methods REQUIRED by CoffeeFolder ---

	-- Determines if the folder contains sequential numeric keys (behaving like an array/tuple).
	-- Returns true if it is an array/tuple, or false if it is a dictionary.
	-- @return boolean.
	local function IsArrayORTupleMethod(self : CoffeeFolder) : boolean
		if #self == 0 then
			for k, v in self do
				return false -- default nil (falsy) ~ Not an array or a tuple
			end
		end
		return true
	end

	-- Appends a new value to the end of the folder, provided the folder is an array/tuple.
	-- Automatically wraps raw tables into CoffeeFolders and primitives into CoffeeBaseValues.
	-- @param newValue The value to be wrapped and inserted.
	local function InsertMethod(self : CoffeeFolder, newValue : CoffeeBaseValue | CoffeeFolder | SupportedTypesList | PrimitiveTable)
		if not self:_IsArrayORTuple() then
			warn("Can't :Insert to a Dictionary!")
			return
		end

		local index = #self + 1

		self[index] = newValue
	end

	-- Returns the internal data table containing all children.
	-- @return A dictionary of keys to CoffeeBaseValues or CoffeeFolders.
	local function GetChildrenMethod(self : CoffeeFolder) : {[string | number]: CoffeeFolder | CoffeeBaseValue}
		return self._data
	end

	-- Destroys the Folder and all of its children recursively.
	-- Disconnects all internal signals.
	local function DestroyMethod(self : CoffeeFolder)
		self.Destroying:Fire()
		self.Destroying:DisconnectAll()

		self.ChildAdded:DisconnectAll()
		self.ChildRemoved:DisconnectAll()

		for _, item in pairs(self._data) do
			if item.Destroy then item:Destroy() end
		end

		rawset(self, "_data", nil)
		rawset(self, "_parent", nil)
		rawset(self, "_key", nil)

		setmetatable(self, nil)
	end

	--- /E Methods REQUIRED by CoffeeFolder ---









	--- Replicate The Way BaseValue Instances Work (Somewhat Accurate) ---

	local supportedTypes = {
		string = true, number = true, boolean = true,
		BrickColor = true, CFrame = true, Color3 = true,
		ColorSequence = true, Content = true, EnumItem = true,
		Font = true, NumberRange = true, NumberSequence = true,
		Ray = true, Rect = true, UDim = true, UDim2 = true, Vector2 = true, Vector3 = true,
	}
	local supportedTypesArray = {}
	local supportedTypesTemp = {}
	for key, _ in pairs(supportedTypes) do
		table.insert(supportedTypesTemp, key)
		local tempConcat = table.concat(supportedTypesTemp, ", ")
		if #tempConcat >= 36 then
			table.insert(supportedTypesArray, tempConcat)
			supportedTypesTemp = {}
		end
	end
	local supportedTypesDebugMessage = table.concat(supportedTypesArray, ",\n>\t")
	supportedTypesArray = nil
	supportedTypesTemp = nil



	local Value = {}

	-- Handles assignment to the Value instance, enforcing type validation for the Value property.
	-- Fires the Changed signal when the Value property is updated.
	-- @param key The key being assigned to (e.g., "Value").
	-- @param newValue The new value to assign. For "Value", must be one of SupportedTypesList.
	function Value:__newindex(key, newValue)
		if key == "Value" then
			assert(supportedTypes[typeof(newValue)], `\n>\tCoffeeBaseValue Does Not Support typeof: "{typeof(newValue)}";\n>\tAll supported Types:\n>\t{supportedTypesDebugMessage};`)

			local previousValue = self._Value
			self._Value = newValue
			self.Changed:Fire(previousValue, newValue)

			return
		end

		rawset(self, key, newValue)
	end

	-- Retrieves the value of a key from the Value instance, returning the stored value for the Value property.
	-- @param key The key to access (e.g., "Value").
	-- @return The value associated with the key, or the stored _Value for "Value".
	function Value:__index(key)
		if key == "Value" then
			return self._Value
		end
		return rawget(Value, key)
	end

	-- Returns a string representation of the Value instance in the format "type: value".
	-- Auto fired when doing print(Value)
	-- @return A string describing the type and value of the instance.
	function Value:__tostring()
		return `{typeof(self._Value)}: {self._Value}`
	end

	-- Destroys the Value instance, disconnecting all Changed signal callbacks and clearing the metatable.
	function Value:Destroy()
		self.Destroying:Fire()
		self.Destroying:DisconnectAll()
		self.Changed:DisconnectAll()
		setmetatable(self, nil)
	end

	-- Creates a new Value instance with a default value, mimicking Roblox BaseValue instances. (Limited To Supported Types; Supports some types, that BaseValues don't).
	-- @param defaultValue The initial value for the Value instance. Must be one of SupportedTypesList.
	-- @return A Value instance with properties Value, Changed, and Destroy.
	function CoffeeBaseValue.new(defaultValue : SupportedTypesList) : CoffeeBaseValue
		assert(supportedTypes[typeof(defaultValue)], `\n>\tCoffeeBaseValue Does Not Support typeof: "{typeof(defaultValue)}";\n>\tAll supported Types:\n>\t{supportedTypesDebugMessage};`)

		local self = setmetatable({}, Value)
		rawset(self, "_Value", defaultValue)
		rawset(self, "Changed", Signal.new())
		rawset(self, "Destroying", Signal.new())
		rawset(self, "GetPath", GetPathMethod)

		return self
	end

	-- Validates whether a given object is a valid Value instance.
	-- @param v The object to validate.
	-- @return True if the object is a Value instance, false otherwise.
	function CoffeeBaseValue.validateClass(v)
		return getmetatable(v) == Value
	end

	function CoffeeBaseValue.validateUnlinkedClass(v)
		-- rawget is used to avoid triggering Folder:__index when
		-- doing CoffeeBaseValue.validateUnlinkedClass(CoffeeFolder)
		return type(v) == "table"
			and	rawget(v, "_Value") ~= nil
			and	rawget(v, "Changed") ~= nil
			and rawget(v, "Destroying") ~= nil
	end









	--- Replicate The Way Folder Instances Work (Somewhat Accurate) ---

	local Folder = {}

	-- Intercepts assignment to the Folder. 
	-- Handles child removal (if nil), wrapping raw data into CoffeeObjects, and parent-linking.
	-- Fires ChildAdded or ChildRemoved signals accordingly.
	-- Overwriting an existing key/index ALWAYS fires ChildRemoved and then ChildAdded, this
	-- is intended behavior in the V2.0.0, unlike the V1.0.0.

	-- Handles the assignment of new children to the Folder.
	-- Automatically wraps raw tables in CoffeeFolders and supported primitives in CoffeeBaseValues.
	-- @param key The key/index for the new child.
	-- @param newValue The value to store. If nil, the child is removed and destroyed.
	function Folder:__newindex(key : string | number, newValue : CoffeeBaseValue | CoffeeFolder | SupportedTypesList | PrimitiveTable)
		--print("new index inside", self)
		--print("kv:", key, newValue)
		local data = rawget(self, "_data")

		local oldItem = rawget(data, key)

		if oldItem then
			if newValue == nil then
				rawset(data, key, nil)
				self.ChildRemoved:Fire(key)

				if oldItem["Destroy"] then oldItem:Destroy() end

				return -- same as return nil
			else
				if oldItem["Destroy"] then oldItem:Destroy() end
			end
		end



		local itemToStore

		if type(newValue) == "table" then
			if CoffeeBaseValue.validateClass(newValue) or CoffeeBaseValue.validateUnlinkedClass(newValue)
				or CoffeeFolder.validateClass(newValue) or CoffeeFolder.validateUnlinkedClass(newValue)	
			then
				--print("A CoffeeBaseValue OR CoffeeFolder")
				itemToStore = newValue -- already a CoffeeObject
			else
				--print("A table, not a CoffeeObject")
				itemToStore = CoffeeFolder.new(newValue)
			end
		else
			--print("Hopefully one of the Supported Types")
			itemToStore = CoffeeBaseValue.new(newValue)
		end

		rawset(itemToStore, "_parent", self)

		rawset(itemToStore, "_key", key)

		-- Listen for child self-destruction
		if itemToStore["Destroying"] then
			itemToStore["Destroying"]:Connect(function()
				local destroyedItem = rawget(data, key)

				if data and destroyedItem == itemToStore then
					rawset(data, key, nil)
					self.ChildRemoved:Fire(key)
				end
			end)
		end

		rawset(data, key, itemToStore)
		self.ChildAdded:Fire(key, itemToStore)
	end

	-- Provides access to children stored in the internal _data table.
	-- @param key The name or index of the child to retrieve.
	-- @return The CoffeeBaseValue or CoffeeFolder associated with the key.
	function Folder:__index(key : string | number)
		return rawget(self._data, key)
	end

	-- Allows the folder to be used in generic 'for' loops (e.g.: for key, child in folder do ... end).
	function Folder:__iter()
		return next, rawget(self, "_data")
	end

	-- Returns the count of children if the folder is an array.
	-- Note: This will return 0 for dictionary-like folders.
	function Folder:__len()
		return #rawget(self, "_data")
	end


	-- Creates a new CoffeeFolder instance, mimicking a Roblox Folder Instance.
	-- @param data Optional initial table to populate the folder with.
	-- @return A CoffeeFolder instance with ChildAdded, ChildRemoved, and tree-traversal methods.
	function CoffeeFolder.new(data : {}?) : CoffeeFolder
		local self = setmetatable({}, Folder)
		rawset(self, "_data", {})
		rawset(self, "ChildAdded", Signal.new())
		rawset(self, "ChildRemoved", Signal.new())
		rawset(self, "Destroying", Signal.new())
		rawset(self, "_IsArrayORTuple", IsArrayORTupleMethod)
		rawset(self, "Insert", InsertMethod)
		rawset(self, "GetPath", GetPathMethod)
		rawset(self, "GetChildren", GetChildrenMethod)
		rawset(self, "Destroy", DestroyMethod)

		if type(data) ~= "table" then
			return self
		end

		--print("Adding", data, "into a coffeefolder")
		for k, v in pairs(data) do
			self[k] = v -- newindex will handle this
		end

		return self
	end

	-- Validates whether a given object is a valid CoffeeFolder instance.
	-- @param v The object to validate.
	-- @return True if the object is a CoffeeFolder instance, false otherwise.
	function CoffeeFolder.validateClass(v)
		return getmetatable(v) == Folder
	end

	-- Validates whether a given table mimics the structure of a CoffeeFolder. (Useful when metatable is lost after a DeepCopy)
	-- @param v The object to validate.
	-- @return True if the object has the required internal Folder properties.
	function CoffeeFolder.validateUnlinkedClass(v)
		return type(v) == "table"
			and	rawget(v, "_data") ~= nil
			and	rawget(v, "ChildAdded") ~= nil
			and	rawget(v, "ChildRemoved") ~= nil
			and rawget(v, "Destroying") ~= nil
	end
end

local CoffeeParser -- (Almost)Standalone CoffeeParser for portable version (3) of ProfileService
--- Derived from https://github.com/Coffilhg/Coffee-Components-Plugin/blob/main/CoffeeComponents/CopyInstance.luau
--- CoffeeParser REQUIRES CoffeeBaseValue AND CoffeeFolder ---
do	
	local debugEnabled = false
	local debugSeverity = 0

	-- Warns with the given message if debugging is enabled and the severity meets the threshold.
	-- Severity levels: 0 = info (e.g., out-of-range warnings), 1 = warning (e.g., invalid input), 2+ = error (e.g., critical failures).
	local function doWarn(warningSeverity : number, ...)
		if not debugEnabled then
			return
		end
		if warningSeverity < debugSeverity then
			return
		end
		warn(...)
	end

	local precision = 3
	local encodePrefix = "_C-"
	local prefixMatchPattern = `^{encodePrefix}`
	local decodeSubLength = #encodePrefix+1

	--- Parser Main ---
	local function round(v)
		local stringR = string.format("%."..precision.."f", v)
		for i = 0, precision-1 do
			local number = math.round(v*10^i)/10^i
			if number == tonumber(stringR) then
				return tostring(number)
			end
		end

		return stringR
		--return tonumber(string.format("%."..precision.."f", v))
	end
	function tostringVector3OrAlikes(v, hideWrap)
		return `{hideWrap and "" or "Vector3("}{round(v.X)}|{round(v.Y)}|{round(v.Z)}`
	end
	local RobloxDatatypeCallbacksEncode = {
		--Axes = function(v : Axes) -- hard to compress, rarely used for player data / game data / admin settings
		--	return `Axes({v})`
		--end,
		EnumItem = function(v : EnumItem)
			-- decode via Enum.EasingDirection:FromValue(v.Value)
			return `EnumItem({v.EnumType}|{v.Value}`
		end,
		BrickColor = function(v : BrickColor)
			return `BrickColor({v.Number}` --- do BrickColor.new(v.Number) to decode
		end,
		CFrame = function(v)
			local pos = v.Position
			local right = v.RightVector
			local up = v.UpVector
			--local look = v.LookVector -- unnecessary/not required for replication
			--- CFrame.fromMatrix
			return `CFrame({tostringVector3OrAlikes(pos, true)}|{tostringVector3OrAlikes(right, true)}|{tostringVector3OrAlikes(up, true)}`
		end,
		Color3 = function(v : Color3)
			return `Color3({v:ToHex()}`
		end,
		ColorSequence = function(v : ColorSequence)
			local result = "ColorSequence("
			local splits = v.Keypoints :: {ColorSequenceKeypoint}
			local isComplex = true

			if #splits == 2 then
				local split1 = splits[1]
				local splitColor1 = Color3.new(split1.Value.R, split1.Value.G, split1.Value.B):ToHex()
				local split2 = splits[2]
				local splitColor2 = Color3.new(split2.Value.R, split2.Value.G, split2.Value.B):ToHex()
				if splitColor1 == splitColor2 then
					result = result .. splitColor1
					isComplex = false
				end
			end
			if isComplex then
				for i, split : ColorSequenceKeypoint in ipairs(splits) do
					local splitColor = Color3.new(split.Value.R, split.Value.G, split.Value.B)
					-- ColorSequenceKeypoint.new
					result = result .. `{round(split.Time)}|{splitColor:ToHex()}{i == #splits and "" or `|`}`
				end
			end

			--result = result ..")"
			return result
		end,
		Content = function(v : Content)
			if v.SourceType == Enum.ContentSourceType.Uri then
				--.fromUri
				return `Content({v.Uri}`
				--elseif v.SourceType == Enum.ContentSourceType.Object then
				--.fromObject
				--	return `Content.O({v.Object})` -- can't parse Object to string
				--elseif v.SourceType == Enum.ContentSourceType.None then
				--	return `Content.none`
			end
			return `Content(`
		end,
		--ContentId = function(v) -- wouldn't that classify as a string anyways?
		--	return `{v}`
		--end,
		--Faces = function(v)
		--	return `Faces({v}`
		--end,
		Font = function(v : Font)
			return `Font({v.Family}|{v.Weight.Value}|{v.Style.Value}`
		end,
		NumberRange = function(v)
			local min, max = round(v.Min), round(v.Max)
			if min == max then
				return `NumberRange({max}`
			else
				return `NumberRange({min}|{max}`
			end
		end,
		NumberSequence = function(v : NumberSequence)
			local result = "NumberSequence("
			local splits = v.Keypoints :: {NumberSequenceKeypoint}
			local isComplex = true

			if #splits == 2 then
				local split1 = splits[1].Value
				local split2 = splits[2].Value
				if split1 == split2 then
					result = result .. `{round(split1)}`
					isComplex = false
				end
			end
			if isComplex then
				for i, split : NumberSequenceKeypoint in ipairs(splits) do
					-- NumberSequenceKeypoint.new
					result = result .. `{round(split.Time)}|{round(split.Value)}|{round(split.Envelope)}{i == #splits and "" or `|`}`
				end
			end

			--result = result .. ")"
			return result
		end,
		Ray = function(v)
			local origin, direction = v.Origin, v.Direction
			return `Ray({tostringVector3OrAlikes(origin, true)}|{tostringVector3OrAlikes(direction, true)}`
		end,
		Rect = function(v)
			local min, max = v.Min, v.Max
			return `Rect({math.round(min.X)}|{math.round(min.Y)}|{math.round(max.X)}|{math.round(max.Y)}`
		end,
		UDim = function(v)
			return `UDim({round(v.Scale)}|{math.round(v.Offset)}`
		end,
		UDim2 = function(v : UDim2)
			return `UDim2({round(v.X.Scale)}|{math.round(v.X.Offset)}|{round(v.Y.Scale)}|{math.round(v.Y.Offset)}`
		end,
		Vector2 = function(v)
			return `Vector2({round(v.X)}|{round(v.Y)}`
		end,
		Vector3 = tostringVector3OrAlikes,
	}
	local RobloxDatatypeCallbacksDecode = {
		--Axes = function(v : Axes) -- hard to compress, rarely used for player data / game data / admin settings
		--	return `Axes({v})`
		--end,
		-- Expects v to be the string after "Enum(" (e.g., "EasingDirection|1" for "_C-Enum(EasingDirection|1" ).
		-- Splits v on "|" to extract enum type and value, then uses Enum[enumTypeName]:FromValue(enumValue) to create an EnumItem.
		-- Returns (EnumItem, true) on success or (nil, false) with a warning on failure.
		EnumItem = function(v: string): (EnumItem?, boolean)
			local parts = v:split("|")
			if not parts or #parts < 2 or #parts[1] < 1 or #parts[2] < 1 then
				doWarn(1, `Malformed EnumItem value, expected EnumType|Value: {v}`)
				return nil, false
			end

			local enumTypeName, enumValueStr = parts[1], parts[2]
			local enumValue = tonumber(enumValueStr)
			if not enumValue then
				doWarn(2, `Failed to convert EnumItem value to number: {enumValueStr}`)
				return nil, false -- Shouldn't happen due to digit check, but included for robustness
			end

			local enumType = Enum[enumTypeName]
			if not enumType then
				doWarn(1, `Invalid Enum type: {enumTypeName}`)
				return nil, false
			end

			local enumItem = enumType:FromValue(enumValue)
			if not enumItem then
				doWarn(1, `Invalid Enum value for {enumTypeName}: {enumValue}`)
				return nil, false
			end

			return enumItem, true
		end,
		-- Expects v to be the numeric string after "BrickColor(" (e.g., "194" for "_C-BrickColor(194" ).
		-- Returns BrickColor.new(number) or (nil, false) for invalid inputs.
		BrickColor = function(v : string): (BrickColor?, boolean)
			local brickColorValue = tonumber(v)
			if not brickColorValue then
				doWarn(1, `Invalid BrickColor value, expected a number: {v}`)
				return nil, false -- Brick Color Value is not a number
			end

			if brickColorValue < 0 or brickColorValue > 1032 then
				doWarn(0, `BrickColor value out of range (0-1032): {brickColorValue}, may default to Medium stone grey`)
			end

			return BrickColor.new(brickColorValue), true
		end,
		-- Expects v to be the string after "CFrame(" (e.g., "0|0|0|1|0|0|0|1|0" for "_C-CFrame(0|0|0|1|0|0|0|1|0" ).
		-- Splits v on "|" to extract 9 numbers (x,y,z for Position, x,y,z for RightVector, x,y,z for UpVector).
		-- Uses CFrame.fromMatrix(Position, RightVector, UpVector) to reconstruct the CFrame.
		-- Returns (CFrame, true) on success or (nil, false) with a warning on failure.
		-- Empty input is handled by tryDecode.
		CFrame = function(v: string): (CFrame?, boolean)
			local parts = v:split("|")
			if not parts or #parts ~= 9 then
				doWarn(1, `Malformed CFrame value, expected 9 numbers (x|y|z|x|y|z|x|y|z): {v}`)
				return nil, false
			end

			local posX, posY, posZ = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			local rightX, rightY, rightZ = tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
			local upX, upY, upZ = tonumber(parts[7]), tonumber(parts[8]), tonumber(parts[9])
			if not (posX and posY and posZ and rightX and rightY and rightZ and upX and upY and upZ) then
				doWarn(1, `Invalid CFrame component values, expected numbers: {v}`)
				return nil, false
			end

			local pos = Vector3.new(posX, posY, posZ)
			local right = Vector3.new(rightX, rightY, rightZ)
			local up = Vector3.new(upX, upY, upZ)

			-- Optional: Warn if right and up are not orthogonal unit vectors
			if math.abs(right.Magnitude - 1) > 0.001 or math.abs(up.Magnitude - 1) > 0.001 or math.abs(right:Dot(up)) > 0.001 then
				doWarn(0, `CFrame vectors may not be orthogonal unit vectors: right={tostring(right)}, up={tostring(up)}`)
			end

			return CFrame.fromMatrix(pos, right, up), true
		end,
		-- Expects v to be the string after "Color3(" (e.g., "FF0000" for _C-Color3(FF0000)).
		-- Uses Color3.fromHex to reconstruct the Color3 from the hex string.
		-- Returns (Color3, true) on success or (nil, false) with a warning on failure.
		Color3 = function(v: string): (Color3?, boolean)
			if not v:match("^%x%x%x%x%x%x$") then
				doWarn(1, `Invalid Color3 hex value, expected 6-digit hexadecimal: {v}`)
				return nil, false
			end

			local success, color = pcall(Color3.fromHex, v)
			if not success or not color then
				doWarn(1, `Failed to decode Color3 from hex: {v}`)
				return nil, false
			end

			return color, true
		end,
		-- Expects v to be the string after "ColorSequence(" (e.g., "FF0000" for "_C-ColorSequence(FF0000" or "0|FF0000|1|00FF00" for "_C-ColorSequence(0|FF0000|1|00FF00").
		-- For simple cases (single hex color), creates a ColorSequence using ColorSequence.new(Color3.fromHex(hex)).
		-- For complex cases, splits v on "|" to extract time|color pairs, validates each time as a number and each color as a 6-digit hex string, and creates ColorSequenceKeypoint objects.
		-- Warns if keypoint times are outside [0,1] or not sorted (severity 0).
		-- Returns (ColorSequence, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (malformed hex, non-numeric time, or incorrect part count).
		ColorSequence = function(v: string): (ColorSequence?, boolean)
			if not v:find("|") then
				if not v:match("^%x%x%x%x%x%x$") then
					doWarn(1, `Invalid ColorSequence hex value, expected 6-digit hexadecimal: {v}`)
					return nil, false
				end

				local success, color = pcall(Color3.fromHex, v)
				if not success or not color then
					doWarn(1, `Failed to decode Color3 from hex for ColorSequence: {v}`)
					return nil, false
				end

				-- Simple case: two keypoints with the same color at times 0 and 1
				return ColorSequence.new(color), true
			end

			-- Complex case: split by "|" for time|color pairs
			local parts = v:split("|")
			if #parts % 2 ~= 0 then
				doWarn(1, `Malformed ColorSequence value, expected even number of parts (time|color pairs): {v}`)
				return nil, false
			end

			local keypoints = {}
			for i = 1, #parts, 2 do
				local keypointTime = tonumber(parts[i])
				local hexColor = parts[i + 1]

				if not keypointTime then
					doWarn(1, `Invalid time value in ColorSequence, expected a number: {parts[i]}`)
					return nil, false
				end

				if not hexColor:match("^%x%x%x%x%x%x$") then
					doWarn(1, `Invalid Color3 hex value in ColorSequence, expected 6-digit hexadecimal: {hexColor}`)
					return nil, false
				end

				local success, color = pcall(Color3.fromHex, hexColor)
				if not success or not color then
					doWarn(1, `Failed to decode Color3 from hex in ColorSequence: {hexColor}`)
					return nil, false
				end

				table.insert(keypoints, ColorSequenceKeypoint.new(keypointTime, color))
			end

			-- Validate Keypoint Limits
			if #keypoints > 20 then
				doWarn(2, `ColorSequence is limited to 20 Keypoints; Tried Setting {#keypoints} Keypoints`)
				return nil, false
			end

			-- Validate keypoints (e.g., times in [0,1], sorted)
			for i, kp in ipairs(keypoints) do
				if kp.Time < 0 or kp.Time > 1 then
					doWarn(2, `ColorSequence keypoint time out of range [0,1]: {kp.Time}`)
					return nil, false
				end
				if i > 1 and kp.Time < keypoints[i-1].Time then
					doWarn(2, `ColorSequence keypoints not sorted by time: {v}`)
					return nil, false
				end
			end

			return ColorSequence.new(keypoints), true
		end,
		-- Expects v to be the string after "Content(" (e.g., "rbxassetid://6372755229" for "_C-Content(rbxassetid://6372755229").  
		-- Returns Content.fromUri(v) for non-empty input, assuming a URI string.  
		-- Empty input is handled by tryDecode, which returns Content.none for datatype "Content".
		-- Returns (Content, true) on success or (nil, false) with a warning (severity 1) if Content.fromUri fails.  
		Content = function(v: string): (Content?, boolean)
			local success, content = pcall(Content.fromUri, v)
			if not success or not content then
				doWarn(1, `Failed to decode Content from URI: {v}`)
				return nil, false
			end
			return content, true
		end,
		--ContentId = function(v) -- wouldn't that classify as a string anyways?
		--	return `{v}`
		--end,
		--Faces = function(v)
		--	return `Faces({v}`
		--end,
		-- Expects v to be the string after "Font(" (e.g., "rbxasset://fonts/Arial.ttf|400|Normal" for "_C-Font(rbxasset://fonts/Arial.ttf|400|Normal").
		-- Splits v on "|" to extract Family (string), Weight (number or Enum.FontWeight name), and Style (Enum.FontStyle name).
		-- Uses Font.new(Family, Weight, Style) to reconstruct the Font.
		-- Returns (Font, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (malformed format, invalid weight, or invalid style)
		Font = function(v: string): (Font?, boolean)
			local parts = v:split("|")
			if not parts or #parts ~= 3 then
				doWarn(1, `Malformed Font value, expected Family|Weight|Style: {v}`)
				return nil, false
			end

			local family, weightValue, styleValue = parts[1], tonumber(parts[2]), tonumber(parts[3])

			-- Validate Family (non-empty string)
			if #family < 1 then
				doWarn(1, `Invalid Font Family, expected non-empty string: {family}`)
				return nil, false
			end
			if not (weightValue and styleValue) then
				doWarn(1, `Invalid Weight or Style -Font Value, Number expected: weightValue->{weightValue} styleValue->{styleValue}`)
				return nil, false
			end

			-- Validate Weight (number or Enum.FontWeight name)
			local weight = Enum.FontWeight:FromValue(weightValue)
			if not weight then
				doWarn(1, `Invalid Font Weight, expected number or Enum.FontWeight name: {weightValue}`)
				return nil, false
			end

			-- Validate Style (Enum.FontStyle name, e.g., "Normal", "Italic")
			local style = Enum.FontStyle:FromValue(styleValue)
			if not style then
				doWarn(1, `Invalid Font Style, expected Enum.FontStyle name: {styleValue}`)
				return nil, false
			end

			-- Attempt to create Font
			local success, font = pcall(Font.new, family, weight, style)
			if not success or not font then
				doWarn(1, `Failed to create Font with Family={family}, Weight={weightValue}, Style={styleValue}`)
				return nil, false
			end

			return font, true
		end,
		-- Expects v to be the string after "NumberRange(" (e.g., "5|10" for "_C-NumberRange(5|10" or "5" for "_C-NumberRange(5").
		-- Splits v on "|" to extract one or two numbers (Min|Max or single Value for Min=Max).
		-- Uses NumberRange.new(Min, Max) or NumberRange.new(Value) to reconstruct the NumberRange.
		-- Returns (NumberRange, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count)
		NumberRange = function(v: string): (NumberRange?, boolean)
			local parts = v:split("|")

			-- Handle single value case (Min == Max)
			if #parts == 1 then
				local value = tonumber(parts[1])
				if not value then
					doWarn(1, `Invalid NumberRange value, expected a number: {parts[1]}`)
					return nil, false
				end
				return NumberRange.new(value), true
			end

			-- Handle Min|Max case
			if #parts ~= 2 then
				doWarn(1, `Malformed NumberRange value, expected Value or Min|Max: {v}`)
				return nil, false
			end

			local min = tonumber(parts[1])
			local max = tonumber(parts[2])
			if not min or not max then
				doWarn(1, `Invalid NumberRange component values, expected numbers: {v}`)
				return nil, false
			end

			return NumberRange.new(math.min(min, max), math.max(min, max)), true
		end,
		-- Expects v to be the string after "NumberSequence(" (e.g., "0.5" for "_C-NumberSequence(0.5)" or "0|0.5|0|1|1|0" for "_C-NumberSequence(0|0.5|0|1|1|0").
		-- For simple cases (single number), creates a NumberSequence with two keypoints at times 0 and 1 with the same value.
		-- For complex cases, splits v on "|" to extract time|value|envelope triplets, validates each as a number, and creates NumberSequenceKeypoint objects.
		-- Warns if keypoint times are outside [0,1] or not sorted (severity 0).
		-- Returns (NumberSequence, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		NumberSequence = function(v: string): (NumberSequence?, boolean)
			if not v:find("|") then
				local value = tonumber(v)
				if not value then
					doWarn(1, `Invalid NumberSequence value, expected a number: {v}`)
					return nil, false
				end
				-- Simple case: two keypoints with the same value at times 0 and 1
				return NumberSequence.new(value), true
			end

			-- Complex case: split by "|" for time|value|envelope triplets
			local parts = v:split("|")
			if #parts % 3 ~= 0 then
				doWarn(1, `Malformed NumberSequence value, expected triplets (time|value|envelope): {v}`)
				return nil, false
			end

			local keypoints = {}
			for i = 1, #parts, 3 do
				local keypointTime = tonumber(parts[i])
				local keypointValue = tonumber(parts[i + 1])
				local keypointEnvelope = tonumber(parts[i + 2])

				if not keypointTime or not keypointValue or not keypointEnvelope then
					doWarn(1, `Invalid NumberSequence keypoint values, expected numbers: time={parts[i]}, value={parts[i+1]}, envelope={parts[i+2]}`)
					return nil, false
				end

				table.insert(keypoints, NumberSequenceKeypoint.new(keypointTime, keypointValue, math.max(0, keypointEnvelope)))
			end

			-- Validate Keypoint Limits
			if #keypoints > 20 then
				doWarn(2, `NumberSequence is limited to 20 Keypoints; Tried Setting {#keypoints} Keypoints`)
				return nil, false
			end

			-- Validate keypoints (e.g., times in [0,1], sorted)
			for i, kp in ipairs(keypoints) do
				if kp.Time < 0 or kp.Time > 1 then
					doWarn(2, `NumberSequence keypoint time out of range [0,1]: {kp.Time}`)
					return nil, false
				end
				if i > 1 and kp.Time < keypoints[i-1].Time then
					doWarn(2, `NumberSequence keypoints not sorted by time: {v}`)
					return nil, false
				end
			end

			return NumberSequence.new(keypoints), true
		end,

		-- Expects v to be the string after "Ray(" (e.g., "1|2|3|4|5|6" for "_C-Ray(1|2|3|4|5|6").
		-- Splits v on "|" to extract 6 numbers (x|y|z for Origin, x|y|z for Direction).
		-- Uses Ray.new(Origin, Direction) to reconstruct the Ray.
		-- Returns (Ray, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		Ray = function(v: string): (Ray?, boolean)
			local parts = v:split("|")
			if #parts ~= 6 then
				doWarn(1, `Malformed Ray value, expected 6 numbers (x|y|z|x|y|z): {v}`)
				return nil, false
			end

			local originX, originY, originZ = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			local dirX, dirY, dirZ = tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
			if not (originX and originY and originZ and dirX and dirY and dirZ) then
				doWarn(1, `Invalid Ray component values, expected numbers: {v}`)
				return nil, false
			end

			local origin = Vector3.new(originX, originY, originZ)
			local direction = Vector3.new(dirX, dirY, dirZ)
			return Ray.new(origin, direction), true
		end,

		-- Expects v to be the string after "Rect(" (e.g., "1|2|3|4" for "_C-Rect(1|2|3|4)").
		-- Splits v on "|" to extract 4 numbers (minX|minY|maxX|maxY).
		-- Uses Rect.new(minX, minY, maxX, maxY) to reconstruct the Rect.
		-- Returns (Rect, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		Rect = function(v: string): (Rect?, boolean)
			local parts = v:split("|")
			if #parts ~= 4 then
				doWarn(1, `Malformed Rect value, expected 4 numbers (minX|minY|maxX|maxY): {v}`)
				return nil, false
			end

			local minX, minY, maxX, maxY = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
			if not (minX and minY and maxX and maxY) then
				doWarn(1, `Invalid Rect component values, expected numbers: {v}`)
				return nil, false
			end

			return Rect.new(minX, minY, maxX, maxY), true
		end,

		-- Expects v to be the string after "UDim(" (e.g., "0.5|100" for "_C-UDim(0.5|100").
		-- Splits v on "|" to extract 2 numbers (Scale|Offset).
		-- Uses UDim.new(Scale, Offset) to reconstruct the UDim.
		-- Returns (UDim, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		UDim = function(v: string): (UDim?, boolean)
			local parts = v:split("|")
			if #parts ~= 2 then
				doWarn(1, `Malformed UDim value, expected 2 numbers (Scale|Offset): {v}`)
				return nil, false
			end

			local scale, offset = tonumber(parts[1]), tonumber(parts[2])
			if not (scale and offset) then
				doWarn(1, `Invalid UDim component values, expected numbers: {v}`)
				return nil, false
			end

			return UDim.new(scale, offset), true
		end,

		-- Expects v to be the string after "UDim2(" (e.g., "0.5|100|0.25|50" for "_C-UDim2(0.5|100|0.25|50").
		-- Splits v on "|" to extract 4 numbers (xScale|xOffset|yScale|yOffset).
		-- Uses UDim2.new(xScale, xOffset, yScale, yOffset) to reconstruct the UDim2.
		-- Returns (UDim2, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		UDim2 = function(v: string): (UDim2?, boolean)
			local parts = v:split("|")
			if #parts ~= 4 then
				doWarn(1, `Malformed UDim2 value, expected 4 numbers (xScale|xOffset|yScale|yOffset): {v}`)
				return nil, false
			end

			local xScale, xOffset, yScale, yOffset = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
			if not (xScale and xOffset and yScale and yOffset) then
				doWarn(1, `Invalid UDim2 component values, expected numbers: {v}`)
				return nil, false
			end

			return UDim2.new(xScale, xOffset, yScale, yOffset), true
		end,

		-- Expects v to be the string after "Vector2(" (e.g., "1|2" for "_C-Vector2(1|2").
		-- Splits v on "," to extract 2 numbers (x|y).
		-- Uses Vector2.new(x, y) to reconstruct the Vector2.
		-- Returns (Vector2, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		Vector2 = function(v: string): (Vector2?, boolean)
			local parts = v:split("|")
			if #parts ~= 2 then
				doWarn(1, `Malformed Vector2 value, expected 2 numbers (x|y): {v}`)
				return nil, false
			end

			local x, y = tonumber(parts[1]), tonumber(parts[2])
			if not (x and y) then
				doWarn(1, `Invalid Vector2 component values, expected numbers: {v}`)
				return nil, false
			end

			return Vector2.new(x, y), true
		end,

		-- Expects v to be the string after "Vector3(" (e.g., "1|2|3" for "_C-Vector3(1|2|3").
		-- Splits v on "|" to extract 3 numbers (x|y|z).
		-- Uses Vector3.new(x, y, z) to reconstruct the Vector3.
		-- Returns (Vector3, true) on success or (nil, false) with a warning (severity 1) for invalid inputs (non-numeric values or incorrect part count).
		Vector3 = function(v: string): (Vector3?, boolean)
			local parts = v:split("|")
			if #parts ~= 3 then
				doWarn(1, `Malformed Vector3 value, expected 3 numbers (x|y|z): {v}`)
				return nil, false
			end

			local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
			if not (x and y and z) then
				doWarn(1, `Invalid Vector3 component values, expected numbers: {v}`)
				return nil, false
			end

			return Vector3.new(x, y, z), true
		end,
	}

	local function tryEncode(datatype, v)
		local cb = RobloxDatatypeCallbacksEncode[datatype] -- O(1)
		if not cb then
			return `Unknown_{datatype}` -- such will be defaulted (e.g.: Unknown_Color3 would be decoded as Color3.fromHex("FFFFFF"))
		end
		return `{encodePrefix}{cb(v)}`
	end

	local function tryDecode(datatype: string, v: string): (any, boolean)
		if #v < 1 then
			if datatype == "Content" then
				return Content.none, true
			end
			doWarn(1, `Empty {datatype} value: {v}`)
			return nil, false -- Empty string (Malformed input)
		end

		local cb = RobloxDatatypeCallbacksDecode[datatype] -- O(1)
		if not cb then
			return nil, false -- such will be defaulted (e.g.: Unknown_Color3 would be decoded as Color3.fromHex("FFFFFF"))
		end
		return cb(v)
	end

	local function handleNonTableValuesEncode(valueType, resultData, key, value)
		if valueType == "number" or valueType == "string" or valueType == "boolean" then
			if valueType == "number" then
				local stringifiedNumber = tostring(value)
				if stringifiedNumber == "inf" then
					resultData[key] = "math.huge"
					return
				end
				if stringifiedNumber == "-inf" then
					resultData[key] = "-math.huge"
					return
				end
			end
			resultData[key] = value
		else
			resultData[key] = tryEncode(typeof(value), value)
		end
	end

	local function encodeData(data, recursion)
		if debugEnabled and not recursion then
			print("Encoding:", data)
		end

		if CoffeeFolder.validateUnlinkedClass(data) and not CoffeeFolder.validateClass(data) then
			data = data["_data"]
		end

		local resultData = {}
		for key, value in data do
			local valueType = type(value)

			if debugEnabled and not recursion then
				print("Encode:", key, value)
			end

			if valueType == "table" then
				local linkedValidate = CoffeeBaseValue.validateClass(value)
				local unlinkedValidate = CoffeeBaseValue.validateUnlinkedClass(value)
				if linkedValidate or unlinkedValidate then
					--print(value)
					local actualValue = value._Value
					--print(value, actualValue)
					handleNonTableValuesEncode(type(actualValue), resultData, key, actualValue)
				else
					-- true table
					resultData[key] = encodeData(value, true)
				end
			else
				handleNonTableValuesEncode(valueType, resultData, key, value)
			end

			--[[--
			
			if valueType == "table" then
				resultData[key] = encodeData(value, true)
			elseif valueType == "number" or valueType == "string" or valueType == "boolean" then
				if valueType == "number" then
					local stringifiedNumber = tostring(value)
					if stringifiedNumber == "inf" then
						resultData[key] = "math.huge"
						continue
					end
					if stringifiedNumber == "-inf" then
						resultData[key] = "-math.huge"
						continue
					end
				end
				resultData[key] = value
			else
				resultData[key] = tryEncode(typeof(value), value)
			end
			--]]--
		end
		return resultData
	end

	local function decodeData(data, recursion)
		if debugEnabled and not recursion then
			print("Decoding:", data)
		end
		local resultData = CoffeeFolder.new() --
		for key, value in pairs(data) do
			local valueType = type(value)

			if debugEnabled and not recursion then
				print("Decode:", key, value)
			end

			if valueType == "table" then
				resultData[key] = decodeData(value, true)
			elseif valueType == "number" or valueType == "boolean" then
				resultData[key] = CoffeeBaseValue.new(value)
			else -- valueType == "string"
				if value == "math.huge" then
					resultData[key] = CoffeeBaseValue.new(math.huge)
					continue
				elseif value == "-math.huge" then
					resultData[key] = CoffeeBaseValue.new(-math.huge)
					continue
				end

				if not string.match(value, prefixMatchPattern) then
					-- just a usual string
					resultData[key] = CoffeeBaseValue.new(value)
					continue
				end

				local result = string.split(string.sub(value, decodeSubLength), "(")
				if not result then
					resultData[key] = CoffeeBaseValue.new(value)
					continue
				end

				--- attempt decoding (might also be a user string; not likely, but just handling this would be great)
				local datatype = result[1]
				local encodedValue = result[2]

				--print(datatype, encodedValue)

				local decodeResult, decodeSuccess = tryDecode(datatype, encodedValue)

				if not decodeSuccess then
					resultData[key] = CoffeeBaseValue.new(value)
					continue
				end

				resultData[key] = CoffeeBaseValue.new(decodeResult)
			end
			--[[--
			elseif valueType == "number" or valueType == "boolean" then
				resultData[key] = value
			else
				if value == "math.huge" then
					resultData[key] = math.huge
					continue
				elseif value == "-math.huge" then
					resultData[key] = -math.huge
					continue
				end

				if not string.match(value, prefixMatchPattern) then
					-- just a usual string
					resultData[key] = value
					continue
				end

				local result = string.split(string.sub(value, decodeSubLength), "(")
				if not result then
					resultData[key] = value
					continue
				end

				--- attempt decoding (might also be a user string; not likely, but just handling this would be great)
				local datatype = result[1]
				local encodedValue = result[2]

				--print(datatype, encodedValue)

				local decodeResult, decodeSuccess = tryDecode(datatype, encodedValue)

				if not decodeSuccess then
					resultData[key] = value
					continue
				end

				resultData[key] = decodeResult
			end
			--]]--
		end
		return resultData
	end

	CoffeeParser = {Encode = encodeData, Decode = decodeData}
end

----- Private -----

local ActiveSessionCheck = {} -- {[session_token] = profile, ...}
local AutoSaveList = {} -- {profile, ...} -- Loaded profile table which will be circularly auto-saved
local IssueQueue = {} -- {issue_time, ...}

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local JobId = game.JobId

local AutoSaveIndex = 1 -- Next profile to auto save
local LastAutoSave = os.clock()

local LoadIndex = 0

local ActiveProfileLoadJobs = 0 -- Number of active threads that are loading in profiles
local ActiveProfileSaveJobs = 0 -- Number of active threads that are saving profiles

local CriticalStateStart = 0 -- os.clock()

local IsStudio = RunService:IsStudio()
local DataStoreState: "NotReady" | "NoInternet" | "NoAccess" | "Access" = "NotReady"

local MockStore = {}
local UserMockStore = {}
local MockFlag = false

local OnError = Signal.new() -- (message, store_name, profile_key)
local OnOverwrite = Signal.new() -- (store_name, profile_key)

local UpdateQueue = { -- For stability sake, we won't do UpdateAsync calls for the same key until all previous calls finish
	--[[
		[session_token] = {
			coroutine, ...
		},
		...
	--]]
}

local function WaitInUpdateQueue(session_token) --> next_in_queue()

	local is_first = false

	if UpdateQueue[session_token] == nil then
		is_first = true
		UpdateQueue[session_token] = {}
	end

	local queue = UpdateQueue[session_token]

	if is_first == false then
		table.insert(queue, coroutine.running())
		coroutine.yield()
	end

	return function()
		local next_co = table.remove(queue, 1)
		if next_co ~= nil then
			coroutine.resume(next_co)
		else
			UpdateQueue[session_token] = nil
		end
	end

end

local function SessionToken(store_name, profile_key, is_mock)

	local session_token = "L_" -- Live

	if is_mock == true then
		session_token = "U_" -- User mock
	elseif DataStoreState ~= "Access" then
		session_token = "M_" -- Mock, cause no DataStore access
	end

	session_token ..= store_name .. "\0" .. profile_key

	return session_token

end

local function DeepCopyTable(t, recursion)
	local copy = {}
	if CoffeeFolder.validateClass(t) then
		for key, value in t do
			if CoffeeFolder.validateClass(value) then
				copy[key] = DeepCopyTable(value, true)
			elseif CoffeeBaseValue.validateClass(value) then
				copy[key] = rawget(value, "_Value")
			else
				if type(value) == "table" then
					copy[key] = DeepCopyTable(value, true)
				else
					copy[key] = value
				end
			end
		end
	else
		for key, value in t do
			if key == "_parent" then
				continue
			end

			if CoffeeFolder.validateClass(value) then
				copy[key] = DeepCopyTable(value, true)
			elseif CoffeeBaseValue.validateClass(value) then
				copy[key] = rawget(value, "_Value")
			else
				if type(value) == "table" then
					copy[key] = DeepCopyTable(value, true)
				else
					copy[key] = value
				end
			end
		end
	end
	if not recursion then
		print("DeepCopy:", copy)
	end
	return copy
end

local function ReconcileTable(target, template)
	--print(`Reconciling: target, template =`, target, template, "\n\n\n")
	for k, v in pairs(template) do
		if type(k) ~= "string" then -- Only string keys will be reconciled
			continue
		end
		--print(k, CoffeeFolder.validateClass(target[k]))
		if target[k] == nil then
			if type(v) == "table" then
				-- ohh, using template and not v??? That was the Messup reason
				target[k] = CoffeeFolder.new(v) -- DeepCopyTable(v)
			else
				target[k] = CoffeeBaseValue.new(v) --v
			end
		elseif (CoffeeFolder.validateClass(target[k]) or CoffeeFolder.validateUnlinkedClass(target[k])) and type(v) == "table" then
			ReconcileTable(target[k], v)
		end
	end
end

--[[
-- this is the version of "ReconcileTable Messing up everything when an entirely new key is added to the PROFILE_TEMPLATE"
local function ReconcileTable(target, template)
	for k, v in pairs(template) do
		if type(k) ~= "string" then -- Only string keys will be reconciled
			continue
		end
		
		if target[k] == nil then
			if type(v) == "table" then
				target[k] = CoffeeFolder.new(template) -- DeepCopyTable(v)
			else
				target[k] = CoffeeBaseValue.new(v) --v
			end
		elseif type(target[k]) == "table" and type(v) == "table" then
			ReconcileTable(target[k], v)
		end
	end
end
]]

local function RegisterError(error_message, store_name, profile_key) -- Called when a DataStore API call errors
	warn(`[{script.Name}]: DataStore API error (STORE:{store_name}; KEY:{profile_key}) - {tostring(error_message)}`)
	table.insert(IssueQueue, os.clock()) -- Adding issue time to queue
	OnError:Fire(tostring(error_message), store_name, profile_key)
end

local function RegisterOverwrite(store_name, profile_key) -- Called when a corrupted profile is loaded
	warn(`[{script.Name}]: Invalid profile was overwritten (STORE:{store_name}; KEY:{profile_key})`)
	OnOverwrite:Fire(store_name, profile_key)
end

local function NewMockDataStoreKeyInfo(params)

	local version_id_string = tostring(params.VersionId or 0)
	local meta_data = params.MetaData or {}
	local user_ids = params.UserIds or {}

	return {
		CreatedTime = params.CreatedTime,
		UpdatedTime = params.UpdatedTime,
		Version = string.rep("0", 16) .. "."
			.. string.rep("0", 10 - string.len(version_id_string)) .. version_id_string
			.. "." .. string.rep("0", 16) .. "." .. "01",

		GetMetadata = function()
			return DeepCopyTable(meta_data)
		end,

		GetUserIds = function()
			return DeepCopyTable(user_ids)
		end,
	}

end

local function MockUpdateAsync(mock_data_store, profile_store_name, key, transform_function, is_get_call) --> loaded_data, key_info

	local profile_store = mock_data_store[profile_store_name]

	if profile_store == nil then
		profile_store = {}
		mock_data_store[profile_store_name] = profile_store
	end

	local epoch_time = math.floor(os.time() * 1000)
	local mock_entry = profile_store[key]
	local mock_entry_was_nil = false

	if mock_entry == nil then
		mock_entry_was_nil = true
		if is_get_call ~= true then
			mock_entry = {
				Data = nil,
				CreatedTime = epoch_time,
				UpdatedTime = epoch_time,
				VersionId = 0,
				UserIds = {},
				MetaData = {},
			}
			profile_store[key] = mock_entry
		end
	end

	local mock_key_info = mock_entry_was_nil == false and NewMockDataStoreKeyInfo(mock_entry) or nil

	local transform, user_ids, roblox_meta_data = transform_function(mock_entry and mock_entry.Data, mock_key_info)

	if transform == nil then
		return nil
	else
		if mock_entry ~= nil and is_get_call ~= true then
			mock_entry.Data = DeepCopyTable(transform)
			mock_entry.UserIds = DeepCopyTable(user_ids or {})
			mock_entry.MetaData = DeepCopyTable(roblox_meta_data or {})
			mock_entry.VersionId += 1
			mock_entry.UpdatedTime = epoch_time
		end

		return DeepCopyTable(transform), mock_entry ~= nil and NewMockDataStoreKeyInfo(mock_entry) or nil
	end

end

local function UpdateAsync(profile_store, profile_key, transform_params, is_user_mock, is_get_call, version) --> loaded_data, key_info
	--transform_params = {
	--	ExistingProfileHandle = function(latest_data),
	--	MissingProfileHandle = function(latest_data),
	--	EditProfile = function(latest_data),
	--}

	local loaded_data, key_info

	local next_in_queue = WaitInUpdateQueue(SessionToken(profile_store.Name, profile_key, is_user_mock))

	local success = true

	local success, error_message = pcall(function()
		local transform_function = function(latest_data)

			local missing_profile = false
			local overwritten = false
			local global_updates = {0, {}}

			if latest_data == nil then

				missing_profile = true

			elseif type(latest_data) ~= "table" then

				missing_profile = true
				overwritten = true

			else

				if type(latest_data.Data) == "table" and type(latest_data.MetaData) == "table" and type(latest_data.GlobalUpdates) == "table" then
					
					--print("Decode screnario 002")
					latest_data.Data = CoffeeParser.Decode(latest_data.Data)
					
					-- Regular profile structure detected:

					latest_data.WasOverwritten = false -- Must be set to false if set previously
					global_updates = latest_data.GlobalUpdates

					if transform_params.ExistingProfileHandle ~= nil then
						transform_params.ExistingProfileHandle(latest_data)
					end

				elseif latest_data.Data == nil and latest_data.MetaData == nil and type(latest_data.GlobalUpdates) == "table" then

					-- Regular structure not detected, but GlobalUpdate data exists:

					latest_data.WasOverwritten = false -- Must be set to false if set previously
					global_updates = latest_data.GlobalUpdates or global_updates
					missing_profile = true

				else

					missing_profile = true
					overwritten = true

				end

			end

			-- Profile was not created or corrupted and no GlobalUpdate data exists:
			if missing_profile == true then
				latest_data = {
					-- Data = nil,
					-- MetaData = nil,
					GlobalUpdates = global_updates,
				}
				if transform_params.MissingProfileHandle ~= nil then
					transform_params.MissingProfileHandle(latest_data)
				end
			end

			-- Editing profile:
			if transform_params.EditProfile ~= nil then
				transform_params.EditProfile(latest_data)
			end

			-- Invalid data handling (Silently override with empty profile)
			if overwritten == true then
				latest_data.WasOverwritten = true -- Temporary tag that will be removed on first save
			end
			
			local encoded_data = DeepCopyTable(latest_data)
			encoded_data["Data"] = CoffeeParser.Encode(encoded_data["Data"])

			--return latest_data, latest_data.UserIds, latest_data.RobloxMetaData
			return encoded_data, latest_data.UserIds, latest_data.RobloxMetaData
		end

		if is_user_mock == true then -- Used when the profile is accessed through ProfileStore.Mock

			loaded_data, key_info = MockUpdateAsync(UserMockStore, profile_store.Name, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield

		elseif DataStoreState ~= "Access" then -- Used when API access is disabled

			loaded_data, key_info = MockUpdateAsync(MockStore, profile_store.Name, profile_key, transform_function, is_get_call)
			task.wait() -- Simulate API call yield

		else

			if is_get_call == true then

				if version ~= nil then

					local success, error_message = pcall(function()
						loaded_data, key_info = profile_store.data_store:GetVersionAsync(profile_key, version)
					end)

					if success == false and type(error_message) == "string" and string.find(error_message, "not valid") ~= nil then
						warn(`[{script.Name}]: Passed version argument is not valid; Traceback:\n` .. debug.traceback())
					end

				else

					loaded_data, key_info = profile_store.data_store:GetAsync(profile_key)

				end

				loaded_data = transform_function(loaded_data)

			else

				loaded_data, key_info = profile_store.data_store:UpdateAsync(profile_key, transform_function)

			end

		end

	end)

	next_in_queue()

	if success == true and type(loaded_data) == "table" then
		-- Invalid data handling:
		if loaded_data.WasOverwritten == true and is_get_call ~= true then
			RegisterOverwrite(
				profile_store.Name,
				profile_key
			)
		end
		-- Return loaded_data:
		return loaded_data, key_info
	else
		-- Error handling:
		RegisterError(
			error_message or "Undefined error",
			profile_store.Name,
			profile_key
		)
		-- Return nothing:
		return nil
	end

end

local function IsThisSession(session_tag)
	return session_tag[1] == PlaceId and session_tag[2] == JobId
end

local function ReadMockFlag(): boolean
	local is_mock = MockFlag
	MockFlag = false
	return is_mock
end

local function WaitForStoreReady(profile_store)
	while profile_store.is_ready == false do
		task.wait()
	end
end

local function AddProfileToAutoSave(profile)

	ActiveSessionCheck[profile.session_token] = profile

	-- Add at AutoSaveIndex and move AutoSaveIndex right:

	table.insert(AutoSaveList, AutoSaveIndex, profile)

	if #AutoSaveList > 1 then
		AutoSaveIndex = AutoSaveIndex + 1
	elseif #AutoSaveList == 1 then
		-- First profile created - make sure it doesn't get immediately auto saved:
		LastAutoSave = os.clock()
	end

end

local function RemoveProfileFromAutoSave(profile)

	ActiveSessionCheck[profile.session_token] = nil

	local auto_save_index = table.find(AutoSaveList, profile)

	if auto_save_index ~= nil then
		table.remove(AutoSaveList, auto_save_index)
		if auto_save_index < AutoSaveIndex then
			AutoSaveIndex = AutoSaveIndex - 1 -- Table contents were moved left before AutoSaveIndex so move AutoSaveIndex left as well
		end
		if AutoSaveList[AutoSaveIndex] == nil then -- AutoSaveIndex was at the end of the AutoSaveList - reset to 1
			AutoSaveIndex = 1
		end
	end

end

local function SaveProfileAsync(profile, is_ending_session, is_overwriting, last_save_reason)

	if type(profile.Data) ~= "table" then
		error(`[{script.Name}]: Developer code likely set "Profile.Data" to a non-table value! (STORE:{profile.ProfileStore.Name}; KEY:{profile.Key})`)
	end

	profile.OnSave:Fire()
	if is_ending_session == true then
		profile.OnLastSave:Fire(last_save_reason or "Manual")
	end

	if is_ending_session == true and is_overwriting ~= true then
		if profile.roblox_message_subscription ~= nil then
			profile.roblox_message_subscription:Disconnect()
		end
		RemoveProfileFromAutoSave(profile)
		profile.OnSessionEnd:Fire()
	end

	ActiveProfileSaveJobs = ActiveProfileSaveJobs + 1

	-- Compare "SessionLoadCount" when writing to profile to prevent a rare case of repeat last save when the profile is loaded on the same server again

	local repeat_save_flag = true -- Released Profile save calls have to repeat until they succeed
	local exp_backoff = 1

	while repeat_save_flag == true do

		if is_ending_session ~= true then
			repeat_save_flag = false
		end

		local loaded_data, key_info = UpdateAsync(
			profile.ProfileStore,
			profile.Key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)

					-- Check if this session still owns the profile:

					local session_owns_profile = false

					if is_overwriting ~= true then

						local active_session = latest_data.MetaData.ActiveSession
						local session_load_count = latest_data.MetaData.SessionLoadCount

						if type(active_session) == "table" then
							session_owns_profile = IsThisSession(active_session) and session_load_count == profile.load_index
						end

					else
						session_owns_profile = true
					end

					-- We may only edit the profile if this server has ownership of the profile:

					if session_owns_profile == true then

						-- Clear processed updates (messages):

						local locked_updates = profile.locked_global_updates -- [index] = true, ...
						local active_updates = latest_data.GlobalUpdates[2]
						-- ProfileService module format: {{update_id, version_id, update_locked, update_data}, ...}
						-- ProfileStore module format: {{update_id, update_data}, ...}

						if next(locked_updates) ~= nil then
							local i = 1
							while i <= #active_updates do
								local update = active_updates[i]
								if locked_updates[update[1]] == true then
									table.remove(active_updates, i)
								else
									i += 1
								end
							end
						end

						-- Save profile data:

						latest_data.Data = profile.Data
						latest_data.RobloxMetaData = profile.RobloxMetaData
						latest_data.UserIds = profile.UserIds

						if is_overwriting ~= true then

							latest_data.MetaData.LastUpdate = os.time()

							if is_ending_session == true then
								latest_data.MetaData.ActiveSession = nil
							end

						else

							latest_data.MetaData.ActiveSession = nil
							latest_data.MetaData.ForceLoadSession = nil

						end

					end

				end,
			},
			profile.is_mock
		)

		if loaded_data ~= nil and key_info ~= nil then

			if is_overwriting == true then
				break
			end

			repeat_save_flag = false

			local active_session = loaded_data.MetaData.ActiveSession
			local session_load_count = loaded_data.MetaData.SessionLoadCount
			local session_owns_profile = false

			if type(active_session) == "table" then
				session_owns_profile = IsThisSession(active_session) and session_load_count == profile.load_index
			end

			local force_load_session = loaded_data.MetaData.ForceLoadSession
			local force_load_pending = false
			if type(force_load_session) == "table" then
				force_load_pending = not IsThisSession(force_load_session)
			end

			local is_active = profile:IsActive()

			-- If another server is trying to start a session for this profile - end the session:

			if force_load_pending == true and session_owns_profile == true then
				if is_active == true then
					SaveProfileAsync(profile, true, false, "External")
				end
				break
			end

			-- Clearing processed update list / Detecting new updates:

			local locked_updates = profile.locked_global_updates -- [index] = true, ...
			local received_updates = profile.received_global_updates -- [index] = true, ...
			local active_updates = loaded_data.GlobalUpdates[2]

			local new_updates = {} -- {}, ...
			local still_pending = {} -- [index] = true, ...

			for _, update in ipairs(active_updates) do
				if locked_updates[update[1]] == true then
					still_pending[update[1]] = true
				elseif received_updates[update[1]] ~= true then
					received_updates[update[1]] = true
					table.insert(new_updates, update)
				end
			end

			for index in pairs(locked_updates) do
				if still_pending[index] ~= true then
					locked_updates[index] = nil
				end
			end

			-- Updating profile values:

			profile.KeyInfo = key_info
			profile.LastSavedData = loaded_data.Data
			profile.global_updates = loaded_data.GlobalUpdates and loaded_data.GlobalUpdates[2] or {}

			if session_owns_profile == true then
				if is_active == true and is_ending_session ~= true then

					-- Processing new global updates (messages):

					for _, update in ipairs(new_updates) do

						local index = update[1]
						local update_data = update[#update] -- Backwards compatibility with ProfileService

						for _, handler in ipairs(profile.message_handlers) do

							local is_processed = false
							local processed_callback = function()
								is_processed = true
								locked_updates[index] = true
							end

							local send_update_data = DeepCopyTable(update_data)

							task.spawn(handler, send_update_data, processed_callback)

							if is_processed == true then
								break
							end

						end

					end

				end
			else

				if profile.roblox_message_subscription ~= nil then
					profile.roblox_message_subscription:Disconnect()
				end

				if is_active == true then
					RemoveProfileFromAutoSave(profile)
					profile.OnSessionEnd:Fire()
				end

			end

			profile.OnAfterSave:Fire(profile.LastSavedData)

		elseif repeat_save_flag == true then

			-- DataStore call likely resulted in an error; Repeat the DataStore call shortly
			task.wait(exp_backoff)
			exp_backoff = math.min(if last_save_reason == "Shutdown" then 8 else 20, exp_backoff * 2)

		end

	end

	ActiveProfileSaveJobs = ActiveProfileSaveJobs - 1

end

----- Public -----

--[[
	Saved profile structure:
	
	{
		Data = {},
		
		MetaData = {
			ProfileCreateTime = 0,
			SessionLoadCount = 0,
			ActiveSession = {place_id, game_job_id, unique_session_id} / nil,
			ForceLoadSession = {place_id, game_job_id} / nil,
			LastUpdate = 0, -- os.time()
			MetaTags = {}, -- Backwards compatibility with ProfileService
		},
		
		RobloxMetaData = {},
		UserIds = {},
		
		GlobalUpdates = {
			update_index,
			{
				{update_index, data}, ...
			},
		},
	}

--]]

export type JSONAcceptable = { JSONAcceptable } | { [string]: JSONAcceptable } | number | string | boolean | buffer

export type Profile<T> = {
	Data: T & JSONAcceptable,
	LastSavedData: T & JSONAcceptable,
	FirstSessionTime: number,
	SessionLoadCount: number,
	Session: {PlaceId: number, JobId: string}?,
	RobloxMetaData: JSONAcceptable,
	UserIds: {number},
	KeyInfo: DataStoreKeyInfo,
	OnSave: {Connect: (self: any, listener: () -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnLastSave: {Connect: (self: any, listener: (reason: "Manual" | "External" | "Shutdown") -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnSessionEnd: {Connect: (self: any, listener: () -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnAfterSave: {Connect: (self: any, listener: (last_saved_data: T & JSONAcceptable) -> ()) -> ({Disconnect: (self: any) -> ()})},
	ProfileStore: JSONAcceptable,
	Key: string,

	IsActive: (self: any) -> (boolean),
	Reconcile: (self: any) -> (),
	EndSession: (self: any) -> (),
	AddUserId: (self: any, user_id: number) -> (),
	RemoveUserId: (self: any, user_id: number) -> (),
	MessageHandler: (self: any, fn: (message: JSONAcceptable, processed: () -> ()) -> ()) -> (),
	Save: (self: any) -> (),
	SetAsync: (self: any) -> (),
}

export type VersionQuery<T> = {
	NextAsync: (self: any) -> (Profile<T>?),
}

type ProfileStoreStandard<T> = {
	Name: string,
	StartSessionAsync: (self: any, profile_key: string, params: {Steal: boolean?}) -> (Profile<T>?),
	MessageAsync: (self: any, profile_key: string, message: JSONAcceptable) -> (boolean),
	GetAsync: (self: any, profile_key: string, version: string?) -> (Profile<T>?),
	VersionQuery: (self: any, profile_key: string, sort_direction: Enum.SortDirection?, min_date: DateTime | number | nil, max_date: DateTime | number | nil) -> (VersionQuery<T>),
	RemoveAsync: (self: any, profile_key: string) -> (boolean),
}

export type ProfileStore<T> = {
	Mock: ProfileStoreStandard<T>,
} & ProfileStoreStandard<T>

type ConstantName = "AUTO_SAVE_PERIOD" | "LOAD_REPEAT_PERIOD" | "FIRST_LOAD_REPEAT" | "SESSION_STEAL"
| "ASSUME_DEAD" | "START_SESSION_TIMEOUT" | "CRITICAL_STATE_ERROR_COUNT" | "CRITICAL_STATE_ERROR_EXPIRE"
| "CRITICAL_STATE_EXPIRE" | "MAX_MESSAGE_QUEUE"

export type ProfileStoreModule = {
	IsClosing: boolean,
	IsCriticalState: boolean,
	OnError: {Connect: (self: any, listener: (message: string, store_name: string, profile_key: string) -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnOverwrite: {Connect: (self: any, listener: (store_name: string, profile_key: string) -> ()) -> ({Disconnect: (self: any) -> ()})},
	OnCriticalToggle: {Connect: (self: any, listener: (is_critical: boolean) -> ()) -> ({Disconnect: (self: any) -> ()})},
	DataStoreState: "NotReady" | "NoInternet" | "NoAccess" | "Access",
	New: <T>(store_name: string, template: (T & JSONAcceptable)?) -> (ProfileStore<T>),
	SetConstant: (name: ConstantName, value: number) -> ()
}

local Profile = {}
Profile.__index = Profile

function Profile.New(raw_data, key_info, profile_store, key, is_mock, session_token)
	
	local to_decode = raw_data.Data or {}
	local data = CoffeeParser.Decode(to_decode)
	local session = raw_data.MetaData and raw_data.MetaData.ActiveSession or nil

	local global_updates = raw_data.GlobalUpdates and raw_data.GlobalUpdates[2] or {}
	local received_global_updates = {}

	for _, update in ipairs(global_updates) do
		received_global_updates[update[1]] = true
	end

	local self = {

		Data = data,
		LastSavedData = DeepCopyTable(data),

		FirstSessionTime = raw_data.MetaData and raw_data.MetaData.ProfileCreateTime or 0,
		SessionLoadCount = raw_data.MetaData and raw_data.MetaData.SessionLoadCount or 0,
		Session = session and {PlaceId = session[1], JobId = session[2]},

		RobloxMetaData = raw_data.RobloxMetaData or {},
		UserIds = raw_data.UserIds or {},
		KeyInfo = key_info,

		OnAfterSave = Signal.new(),
		OnSave = Signal.new(),
		OnLastSave = Signal.new(),
		OnSessionEnd = Signal.new(),

		ProfileStore = profile_store,
		Key = key,

		load_timestamp = os.clock(),
		is_mock = is_mock,
		session_token = session_token or "",
		load_index = raw_data.MetaData and raw_data.MetaData.SessionLoadCount or 0,
		locked_global_updates = {},
		received_global_updates = received_global_updates,
		message_handlers = {},
		global_updates = global_updates,

	}
	setmetatable(self, Profile)

	return self

end

function Profile:IsActive()
	return ActiveSessionCheck[self.session_token] == self
end

function Profile:Reconcile()
	--print(`Profile:Reconcile() called; Profile = `, self, `self.ProfileStore.template = `, self.ProfileStore.template)
	ReconcileTable(self.Data, self.ProfileStore.template)
end

function Profile:EndSession()
	if self:IsActive() == true then
		task.spawn(SaveProfileAsync, self, true, nil, "Manual") -- Call save function in a new thread with release_from_session = true
	end
end

function Profile:AddUserId(user_id) -- Associates user_id with profile (GDPR compliance)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn(`[{script.Name}]: Invalid UserId argument for :AddUserId() ({tostring(user_id)}); Traceback:\n` .. debug.traceback())
		return
	end

	if user_id < 0 and self.is_mock ~= true and DataStoreState == "Access" then
		return -- Avoid giving real Roblox APIs negative UserId's
	end

	if table.find(self.UserIds, user_id) == nil then
		table.insert(self.UserIds, user_id)
	end

end

function Profile:RemoveUserId(user_id) -- Removes user_id association with profile (safe function)

	if type(user_id) ~= "number" or user_id % 1 ~= 0 then
		warn(`[{script.Name}]: Invalid UserId argument for :RemoveUserId() ({tostring(user_id)}); Traceback:\n` .. debug.traceback())
		return
	end

	local index = table.find(self.UserIds, user_id)

	if index ~= nil then
		table.remove(self.UserIds, index)
	end

end

function Profile:SetAsync() -- Saves the profile to the DataStore and removes the session lock

	if self.view_mode ~= true then
		error(`[{script.Name}]: :SetAsync() can only be used in view mode`)
	end

	SaveProfileAsync(self, nil, true)

end

function Profile:MessageHandler(fn)

	if type(fn) ~= "function" then
		error(`[{script.Name}]: fn argument is not a function`)
	end

	if self.view_mode ~= true and self:IsActive() ~= true then
		return -- Don't process messages if the profile session was ended
	end

	local locked_updates = self.locked_global_updates
	table.insert(self.message_handlers, fn)

	for _, update in ipairs(self.global_updates) do

		local index = update[1]
		local update_data = update[#update] -- Backwards compatibility with ProfileService

		if locked_updates[index] ~= true then

			local processed_callback = function()
				locked_updates[index] = true
			end

			local send_update_data = DeepCopyTable(update_data)

			task.spawn(fn, send_update_data, processed_callback)

		end

	end

end

function Profile:Save()

	if self.view_mode == true then
		error(`[{script.Name}]: Can't save profile in view mode; Should you be calling :SetAsync() instead?`)
	end

	if self:IsActive() == false then
		warn(`[{script.Name}]: Attempted saving an inactive profile (STORE:{self.ProfileStore.Name}; KEY:{self.Key});`
			.. ` Traceback:\n` .. debug.traceback())
		return
	end

	-- Move the profile right behind the auto save index to delay the next auto save for it:
	RemoveProfileFromAutoSave(self)
	AddProfileToAutoSave(self)

	-- Perform save in new thread:
	task.spawn(SaveProfileAsync, self)

end

local ProfileStore: ProfileStoreModule = {

	IsClosing = false,
	IsCriticalState = false,
	OnError = OnError, -- (message, store_name, profile_key)
	OnOverwrite = OnOverwrite, -- (store_name, profile_key)
	OnCriticalToggle = Signal.new(), -- (is_critical)
	DataStoreState = "NotReady", -- ("NotReady", "NoInternet", "NoAccess", "Access")

}
ProfileStore.__index = ProfileStore

function ProfileStore.SetConstant(name, value)

	if type(value) ~= "number" then
		error(`[{script.Name}]: Invalid value type`)
	end

	if name == "AUTO_SAVE_PERIOD" then
		AUTO_SAVE_PERIOD = value
	elseif name == "LOAD_REPEAT_PERIOD" then
		LOAD_REPEAT_PERIOD = value
	elseif name == "FIRST_LOAD_REPEAT" then
		FIRST_LOAD_REPEAT = value
	elseif name == "SESSION_STEAL" then
		SESSION_STEAL = value
	elseif name == "ASSUME_DEAD" then
		ASSUME_DEAD = value
	elseif name == "START_SESSION_TIMEOUT" then
		START_SESSION_TIMEOUT = value
	elseif name == "CRITICAL_STATE_ERROR_COUNT" then
		CRITICAL_STATE_ERROR_COUNT = value
	elseif name == "CRITICAL_STATE_ERROR_EXPIRE" then
		CRITICAL_STATE_ERROR_EXPIRE = value
	elseif name == "CRITICAL_STATE_EXPIRE" then
		CRITICAL_STATE_EXPIRE = value
	elseif name == "MAX_MESSAGE_QUEUE" then
		MAX_MESSAGE_QUEUE = value
	else
		error(`[{script.Name}]: Invalid constant name was provided`)
	end

end

function ProfileStore.Test()
	return {
		ActiveSessionCheck = ActiveSessionCheck,
		AutoSaveList = AutoSaveList,
		ActiveProfileLoadJobs = ActiveProfileLoadJobs,
		ActiveProfileSaveJobs = ActiveProfileSaveJobs,
		MockStore = MockStore,
		UserMockStore = UserMockStore,
		UpdateQueue = UpdateQueue,
	}
end

function ProfileStore.New(store_name, template)

	template = template or {}

	if type(store_name) ~= "string" then
		error(`[{script.Name}]: Invalid or missing "store_name"`)
	elseif string.len(store_name) == 0 then
		error(`[{script.Name}]: store_name cannot be an empty string`)
	elseif string.len(store_name) > 50 then
		error(`[{script.Name}]: store_name is too long`)
	end

	if type(template) ~= "table" then
		error(`[{script.Name}]: Invalid template argument`)
	end

	local self
	self = {

		Mock = {

			Name = store_name,

			StartSessionAsync = function(_, profile_key)
				MockFlag = true
				return self:StartSessionAsync(profile_key)
			end,
			MessageAsync = function(_, profile_key, message)
				MockFlag = true
				return self:MessageAsync(profile_key, message)
			end,
			GetAsync = function(_, profile_key, version)
				MockFlag = true
				return self:GetAsync(profile_key, version)
			end,
			VersionQuery = function(_, profile_key, sort_direction, min_date, max_date)
				MockFlag = true
				return self:VersionQuery(profile_key, sort_direction, min_date, max_date)
			end,
			RemoveAsync = function(_, profile_key)
				MockFlag = true
				return self:RemoveAsync(profile_key)
			end
		},

		Name = store_name,

		template = template,
		data_store = nil,
		load_jobs = {},
		mock_load_jobs = {},
		is_ready = true,

	}
	setmetatable(self, ProfileStore)

	local options = Instance.new("DataStoreOptions")
	options:SetExperimentalFeatures({v2 = true})

	if DataStoreState == "NotReady" then

		-- The module is not sure whether DataStores are accessible yet:

		self.is_ready = false

		task.spawn(function()

			repeat task.wait() until DataStoreState ~= "NotReady"

			if DataStoreState == "Access" then
				self.data_store = DataStoreService:GetDataStore(store_name, nil, options)
			end

			self.is_ready = true

		end)

	elseif DataStoreState == "Access" then

		self.data_store = DataStoreService:GetDataStore(store_name, nil, options)

	end

	return self

end

local function RobloxMessageSubscription(profile, unique_session_id)

	local last_roblox_message = 0

	local roblox_message_subscription = MessagingService:SubscribeAsync("PS_" .. unique_session_id, function(message)
		if type(message.Data) == "table" and message.Data.LoadCount == profile.SessionLoadCount then
			-- High reaction rate, based on numPlayers × 10 DataStore budget as of writing
			if os.clock() - last_roblox_message > 6 then 
				last_roblox_message = os.clock()
				if profile:IsActive() == true then
					if message.Data.EndSession == true then
						SaveProfileAsync(profile, true, false, "External")
					else
						profile:Save()
					end
				end
			end
		end
	end)

	if profile:IsActive() == true then
		profile.roblox_message_subscription = roblox_message_subscription
	else
		roblox_message_subscription:Disconnect()
	end

end

function ProfileStore:StartSessionAsync(profile_key, params)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if params ~= nil and type(params) ~= "table" then
		error(`[{script.Name}]: Invalid params`)
	end

	params = params or {}

	if ProfileStore.IsClosing == true then
		return nil
	end

	WaitForStoreReady(self)

	local session_token = SessionToken(self.Name, profile_key, is_mock)

	if ActiveSessionCheck[session_token] ~= nil then
		error(`[{script.Name}]: Profile (STORE:{self.Name}; KEY:{profile_key}) is already loaded in this session`)
	end

	ActiveProfileLoadJobs = ActiveProfileLoadJobs + 1

	local is_user_cancel = false

	local function cancel_condition()
		if is_user_cancel == false then
			if params.Cancel ~= nil then
				is_user_cancel = params.Cancel() == true
			end
			return is_user_cancel
		end
		return true
	end

	local user_steal = params.Steal == true

	local force_load_steps = 0 -- Session conflict handling values
	local request_force_load = true
	local steal_session = false

	local start = os.clock()
	local exp_backoff = 1

	while ProfileStore.IsClosing == false and cancel_condition() == false do

		-- Load profile:

		-- SPECIAL CASE - If StartSessionAsync is called for the same key again before another StartSessionAsync finishes,
		-- grab the DataStore return for the new call. The early call will return nil. This is supposed to retain
		-- expected and efficient behavior in cases where a player would quickly rejoin the same server.

		LoadIndex += 1
		local load_id = LoadIndex
		local profile_load_jobs = is_mock == true and self.mock_load_jobs or self.load_jobs
		local profile_load_job = profile_load_jobs[profile_key] -- {load_id, {loaded_data, key_info} or nil}

		local loaded_data, key_info
		local unique_session_id = HttpService:GenerateGUID(false)

		if profile_load_job ~= nil then

			profile_load_job[1] = load_id -- Steal load job
			while profile_load_job[2] == nil do -- Wait for job to finish
				task.wait()
			end
			if profile_load_job[1] == load_id then -- Load job hasn't been double-stolen
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil
			end

		else

			profile_load_job = {load_id, nil}
			profile_load_jobs[profile_key] = profile_load_job

			profile_load_job[2] = table.pack(UpdateAsync(
				self,
				profile_key,
				{
					ExistingProfileHandle = function(latest_data)

						if ProfileStore.IsClosing == true or cancel_condition() == true then
							return
						end

						local active_session = latest_data.MetaData.ActiveSession
						local force_load_session = latest_data.MetaData.ForceLoadSession

						if active_session == nil then
							latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
							latest_data.MetaData.ForceLoadSession = nil
						elseif type(active_session) == "table" then
							if IsThisSession(active_session) == false then
								local last_update = latest_data.MetaData.LastUpdate
								if last_update ~= nil then
									if os.time() - last_update > ASSUME_DEAD then
										latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
										latest_data.MetaData.ForceLoadSession = nil
										return
									end
								end
								if steal_session == true or user_steal == true then
									local force_load_interrupted = if force_load_session ~= nil then not IsThisSession(force_load_session) else true
									if force_load_interrupted == false or user_steal == true then
										latest_data.MetaData.ActiveSession = {PlaceId, JobId, unique_session_id}
										latest_data.MetaData.ForceLoadSession = nil
									end
								elseif request_force_load == true then
									latest_data.MetaData.ForceLoadSession = {PlaceId, JobId}
								end
							else
								latest_data.MetaData.ForceLoadSession = nil
							end
						end

					end,
					MissingProfileHandle = function(latest_data)

						local is_cancel = ProfileStore.IsClosing == true or cancel_condition() == true

						latest_data.Data = DeepCopyTable(self.template)
						latest_data.MetaData = {
							ProfileCreateTime = os.time(),
							SessionLoadCount = 0,
							ActiveSession = if is_cancel == false then {PlaceId, JobId, unique_session_id} else nil,
							ForceLoadSession = nil,
							MetaTags = {}, -- Backwards compatibility with ProfileService
						}

					end,
					EditProfile = function(latest_data)

						if ProfileStore.IsClosing == true or cancel_condition() == true then
							return
						end

						local active_session = latest_data.MetaData.ActiveSession
						if active_session ~= nil and IsThisSession(active_session) == true then
							latest_data.MetaData.SessionLoadCount = latest_data.MetaData.SessionLoadCount + 1
							latest_data.MetaData.LastUpdate = os.time()
						end

					end,
				},
				is_mock
				))
			if profile_load_job[1] == load_id then -- Load job hasn't been stolen
				loaded_data, key_info = table.unpack(profile_load_job[2])
				profile_load_jobs[profile_key] = nil
			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- Load job stolen
			end
		end

		-- Handle load_data:

		if loaded_data ~= nil and key_info ~= nil then
			local active_session = loaded_data.MetaData.ActiveSession
			if type(active_session) == "table" then

				if IsThisSession(active_session) == true then

					-- Profile is now taken by this session:

					local profile = Profile.New(loaded_data, key_info, self, profile_key, is_mock, session_token)
					AddProfileToAutoSave(profile)

					if is_mock ~= true and DataStoreState == "Access" then

						-- Use MessagingService to quickly detect session conflicts and resolve them quickly:
						task.spawn(RobloxMessageSubscription, profile, unique_session_id) -- Blocking prevention

					end

					if ProfileStore.IsClosing == true or cancel_condition() == true then
						-- The server has initiated a shutdown by the time this profile was loaded
						SaveProfileAsync(profile, true) -- Release profile and yield until the DataStore call is finished
						profile = nil -- Don't return the profile object
					end

					ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
					return profile

				else

					if ProfileStore.IsClosing == true or cancel_condition() == true then
						ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
						return nil
					end

					-- Profile is taken by some other session:

					local force_load_session = loaded_data.MetaData.ForceLoadSession
					local force_load_interrupted = if force_load_session ~= nil then not IsThisSession(force_load_session) else true

					if force_load_interrupted == false then

						if request_force_load == false then
							force_load_steps = force_load_steps + 1
							if force_load_steps >= math.ceil(SESSION_STEAL / LOAD_REPEAT_PERIOD) then
								steal_session = true
							end
						end

						-- Request the remote server to end its session:
						if type(active_session[3]) == "string" then
							local session_load_count = loaded_data.MetaData.SessionLoadCount or 0
							task.spawn(MessagingService.PublishAsync, MessagingService, "PS_" .. active_session[3], {LoadCount = session_load_count, EndSession = true})
						end

						-- Attempt to load the profile again after a delay
						local wait_until = os.clock() + if request_force_load == true then FIRST_LOAD_REPEAT else LOAD_REPEAT_PERIOD
						repeat task.wait() until os.clock() >= wait_until or ProfileStore.IsClosing == true

					else
						-- Another session tried to load this profile:
						ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
						return nil
					end

					request_force_load = false -- Only request a force load once

				end

			else
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil -- In this scenario it is likely that this server started shutting down
			end
		else

			-- A DataStore call has likely ended in an error:

			local default_timeout = false

			if params.Cancel == nil then
				default_timeout = os.clock() - start >= START_SESSION_TIMEOUT
			end

			if default_timeout == true or ProfileStore.IsClosing == true or cancel_condition() == true then
				ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
				return nil
			end

			task.wait(exp_backoff)  -- Repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	ActiveProfileLoadJobs = ActiveProfileLoadJobs - 1
	return nil -- Game started shutting down or the request was cancelled - don't return the profile

end

function ProfileStore:MessageAsync(profile_key, message)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if type(message) ~= "table" then
		error(`[{script.Name}]: message must be a table`)
	end

	if ProfileStore.IsClosing == true then
		return false
	end

	WaitForStoreReady(self)

	local exp_backoff = 1

	while ProfileStore.IsClosing == false do

		-- Updating profile:

		local loaded_data = UpdateAsync(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = nil,
				EditProfile = function(latest_data)

					local global_updates = latest_data.GlobalUpdates
					local update_list = global_updates[2]
					--{
					--	update_index,
					--	{
					--		{update_index, data}, ...
					--	},
					--},

					global_updates[1] += 1
					table.insert(update_list, {global_updates[1], message})

					-- Clearing queue if above limit:

					while #update_list > MAX_MESSAGE_QUEUE do
						table.remove(update_list, 1)
					end

				end,
			},
			is_mock
		)

		if loaded_data ~= nil then

			local session_token = SessionToken(self.Name, profile_key, is_mock)

			local profile = ActiveSessionCheck[session_token]

			if profile ~= nil then

				-- The message was sent to a profile that is active in this server:
				profile:Save()

			else

				local meta_data = loaded_data.MetaData or {}
				local active_session = meta_data.ActiveSession
				local session_load_count = meta_data.SessionLoadCount or 0

				if type(active_session) == "table" and type(active_session[3]) == "string" then
					-- Request the remote server to auto-save sooner and receive the message:
					task.spawn(MessagingService.PublishAsync, MessagingService, "PS_" .. active_session[3], {LoadCount = session_load_count})
				end

			end

			return true

		else

			task.wait(exp_backoff) -- A DataStore call has likely ended in an error - repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	return false

end

function ProfileStore:GetAsync(profile_key, version)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" then
		error(`[{script.Name}]: profile_key must be a string`)
	elseif string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	elseif string.len(profile_key) > 50 then
		error(`[{script.Name}]: profile_key is too long`)
	end

	if ProfileStore.IsClosing == true then
		return nil
	end

	WaitForStoreReady(self)

	if version ~= nil and (is_mock or DataStoreState ~= "Access") then
		return nil -- No version support in mock mode
	end

	local exp_backoff = 1

	while ProfileStore.IsClosing == false do

		-- Load profile:

		local loaded_data, key_info = UpdateAsync(
			self,
			profile_key,
			{
				ExistingProfileHandle = nil,
				MissingProfileHandle = function(latest_data)

					latest_data.Data = DeepCopyTable(self.template)
					latest_data.MetaData = {
						ProfileCreateTime = os.time(),
						SessionLoadCount = 0,
						ActiveSession = nil,
						ForceLoadSession = nil,
						MetaTags = {}, -- Backwards compatibility with ProfileService
					}

				end,
				EditProfile = nil,
			},
			is_mock,
			true, -- Use :GetAsync()
			version -- DataStore key version
		)

		-- Handle load_data:

		if loaded_data ~= nil then

			if key_info == nil then
				return nil -- Load was successful, but the key was empty - return no profile object
			end

			local profile = Profile.New(loaded_data, key_info, self, profile_key, is_mock)
			profile.view_mode = true

			return profile

		else

			task.wait(exp_backoff) -- A DataStore call has likely ended in an error - repeat the call shortly
			exp_backoff = math.min(20, exp_backoff * 2)

		end

	end

	return nil -- Game started shutting down - don't return the profile

end

function ProfileStore:RemoveAsync(profile_key)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	end

	if ProfileStore.IsClosing == true then
		return false
	end

	WaitForStoreReady(self)

	local wipe_status = false

	local next_in_queue = WaitInUpdateQueue(SessionToken(self.Name, profile_key, is_mock))

	if is_mock == true then -- Used when the profile is accessed through ProfileStore.Mock

		local mock_data_store = UserMockStore[self.Name]

		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
			if next(mock_data_store) == nil then
				UserMockStore[self.Name] = nil
			end
		end

		wipe_status = true
		task.wait() -- Simulate API call yield

	elseif DataStoreState ~= "Access" then -- Used when API access is disabled

		local mock_data_store = MockStore[self.Name]

		if mock_data_store ~= nil then
			mock_data_store[profile_key] = nil
			if next(mock_data_store) == nil then
				MockStore[self.Name] = nil
			end
		end

		wipe_status = true
		task.wait() -- Simulate API call yield

	else -- Live DataStore

		wipe_status = pcall(function()
			self.data_store:RemoveAsync(profile_key)
		end)

	end

	next_in_queue()

	return wipe_status

end

local ProfileVersionQuery = {}
ProfileVersionQuery.__index = ProfileVersionQuery

function ProfileVersionQuery.New(profile_store, profile_key, sort_direction, min_date, max_date, is_mock)

	local self = {
		profile_store = profile_store,
		profile_key = profile_key,
		sort_direction = sort_direction,
		min_date = min_date,
		max_date = max_date,

		query_pages = nil,
		query_index = 0,
		query_failure = false,

		is_query_yielded = false,
		query_queue = {},

		is_mock = is_mock,
	}
	setmetatable(self, ProfileVersionQuery)

	return self

end

function MoveVersionQueryQueue(self) -- Hidden ProfileVersionQuery method
	while #self.query_queue > 0 do

		local queue_entry = table.remove(self.query_queue, 1)

		task.spawn(queue_entry)

		if self.is_query_yielded == true then
			break
		end

	end
end

local VersionQueryNextAsyncStackingFlag = false
local WarnAboutVersionQueryOnce = false

function ProfileVersionQuery:NextAsync()

	local is_stacking = VersionQueryNextAsyncStackingFlag == true
	VersionQueryNextAsyncStackingFlag = false

	WaitForStoreReady(self.profile_store)

	if ProfileStore.IsClosing == true then
		return nil -- Silently fail :NextAsync() requests
	end

	if self.is_mock == true or DataStoreState ~= "Access" then
		if IsStudio == true and WarnAboutVersionQueryOnce == false then
			WarnAboutVersionQueryOnce = true
			warn(`[{script.Name}]: :VersionQuery() is not supported in mock mode!`)
		end
		return nil -- Silently fail :NextAsync() requests
	end

	local profile
	local is_finished = false

	local function query_job()

		if self.query_failure == true then
			is_finished = true
			return
		end

		-- First "next" call loads version pages:

		if self.query_pages == nil then

			self.is_query_yielded = true

			task.spawn(function()
				VersionQueryNextAsyncStackingFlag = true
				profile = self:NextAsync()
				is_finished = true
			end)

			local list_success, error_message = pcall(function()
				self.query_pages = self.profile_store.data_store:ListVersionsAsync(
					self.profile_key,
					self.sort_direction,
					self.min_date,
					self.max_date
				)
				self.query_index = 0
			end)

			if list_success == false or self.query_pages == nil then
				warn(`[{script.Name}]: Version query fail - {tostring(error_message)}`)
				self.query_failure = true
			end

			self.is_query_yielded = false

			MoveVersionQueryQueue(self)

			return

		end

		local current_page = self.query_pages:GetCurrentPage()
		local next_item = current_page[self.query_index + 1]

		-- No more entries:

		if self.query_pages.IsFinished == true and next_item == nil then
			is_finished = true
			return
		end

		-- Load next page when this page is over:

		if next_item == nil then

			self.is_query_yielded = true
			task.spawn(function()
				VersionQueryNextAsyncStackingFlag = true
				profile = self:NextAsync()
				is_finished = true
			end)

			local success, error_message = pcall(function()
				self.query_pages:AdvanceToNextPageAsync()
				self.query_index = 0
			end)

			if success == false or #self.query_pages:GetCurrentPage() == 0 then
				self.query_failure = true
			end

			self.is_query_yielded = false
			MoveVersionQueryQueue(self)

			return

		end

		-- Next page item:

		self.query_index += 1
		profile = self.profile_store:GetAsync(self.profile_key, next_item.Version)
		is_finished = true

	end

	if self.is_query_yielded == false then
		query_job()
	else
		if is_stacking == true then
			table.insert(self.query_queue, 1, query_job)
		else
			table.insert(self.query_queue, query_job)
		end
	end

	while is_finished == false do
		task.wait()
	end

	return profile

end

function ProfileStore:VersionQuery(profile_key, sort_direction, min_date, max_date)

	local is_mock = ReadMockFlag()

	if type(profile_key) ~= "string" or string.len(profile_key) == 0 then
		error(`[{script.Name}]: Invalid profile_key`)
	end

	-- Type check:

	if sort_direction ~= nil and (typeof(sort_direction) ~= "EnumItem"
		or sort_direction.EnumType ~= Enum.SortDirection) then
		error(`[{script.Name}]: Invalid sort_direction ({tostring(sort_direction)})`)
	end

	if min_date ~= nil and typeof(min_date) ~= "DateTime" and typeof(min_date) ~= "number" then
		error(`[{script.Name}]: Invalid min_date ({tostring(min_date)})`)
	end

	if max_date ~= nil and typeof(max_date) ~= "DateTime" and typeof(max_date) ~= "number" then
		error(`[{script.Name}]: Invalid max_date ({tostring(max_date)})`)
	end

	min_date = typeof(min_date) == "DateTime" and min_date.UnixTimestampMillis or min_date
	max_date = typeof(max_date) == "DateTime" and max_date.UnixTimestampMillis or max_date

	return ProfileVersionQuery.New(self, profile_key, sort_direction, min_date, max_date, is_mock)

end

-- DataStore API access check:

if IsStudio == true then

	task.spawn(function()

		local new_state = "NoAccess"

		local status, message = pcall(function()
			-- This will error if current instance has no Studio API access:
			DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
		end)

		local no_internet_access = status == false and string.find(message, "ConnectFail", 1, true) ~= nil

		if no_internet_access == true then
			warn(`[{script.Name}]: No internet access - check your network connection`)
		end

		if status == false and
			(string.find(message, "403", 1, true) ~= nil or -- Cannot write to DataStore from studio if API access is not enabled
				string.find(message, "must publish", 1, true) ~= nil or -- Game must be published to access live keys
				no_internet_access == true) then -- No internet access

			new_state = if no_internet_access == true then "NoInternet" else "NoAccess"
			print(`[{script.Name}]: Roblox API services unavailable - data will not be saved`)
		else
			new_state = "Access"
			print(`[{script.Name}]: Roblox API services available - data will be saved`)
		end

		DataStoreState = new_state
		ProfileStore.DataStoreState = new_state

	end)

else

	DataStoreState = "Access"
	ProfileStore.DataStoreState = "Access"

end

-- Update loop:

RunService.Heartbeat:Connect(function()

	-- Auto saving:

	local auto_save_list_length = #AutoSaveList
	if auto_save_list_length > 0 then
		local auto_save_index_speed = AUTO_SAVE_PERIOD / auto_save_list_length
		local os_clock = os.clock()
		while os_clock - LastAutoSave > auto_save_index_speed do
			LastAutoSave = LastAutoSave + auto_save_index_speed
			local profile = AutoSaveList[AutoSaveIndex]
			if os_clock - profile.load_timestamp < AUTO_SAVE_PERIOD / 2 then
				-- This profile is freshly loaded - auto saving immediately is not necessary:
				profile = nil
				for _ = 1, auto_save_list_length - 1 do
					-- Move auto save index to the right:
					AutoSaveIndex = AutoSaveIndex + 1
					if AutoSaveIndex > auto_save_list_length then
						AutoSaveIndex = 1
					end
					profile = AutoSaveList[AutoSaveIndex]
					if os_clock - profile.load_timestamp >= AUTO_SAVE_PERIOD / 2 then
						break
					else
						profile = nil
					end
				end
			end
			-- Move auto save index to the right:
			AutoSaveIndex = AutoSaveIndex + 1
			if AutoSaveIndex > auto_save_list_length then
				AutoSaveIndex = 1
			end
			-- Perform save call:
			if profile ~= nil then
				task.spawn(SaveProfileAsync, profile) -- Auto save profile in new thread
			end
		end
	end

	-- Critical state handling:

	if ProfileStore.IsCriticalState == false then
		if #IssueQueue >= CRITICAL_STATE_ERROR_COUNT then
			ProfileStore.IsCriticalState = true
			ProfileStore.OnCriticalToggle:Fire(true)
			CriticalStateStart = os.clock()
			warn(`[{script.Name}]: Entered critical state`)
		end
	else
		if #IssueQueue >= CRITICAL_STATE_ERROR_COUNT then
			CriticalStateStart = os.clock()
		elseif os.clock() - CriticalStateStart > CRITICAL_STATE_EXPIRE then
			ProfileStore.IsCriticalState = false
			ProfileStore.OnCriticalToggle:Fire(false)
			warn(`[{script.Name}]: Critical state ended`)
		end
	end

	-- Issue queue:

	while true do
		local issue_time = IssueQueue[1]
		if issue_time == nil then
			break
		elseif os.clock() - issue_time > CRITICAL_STATE_ERROR_EXPIRE then
			table.remove(IssueQueue, 1)
		else
			break
		end
	end

end)

-- Release all loaded profiles when the server is shutting down:

task.spawn(function()

	while DataStoreState == "NotReady" do
		task.wait()
	end

	if DataStoreState ~= "Access" then

		game:BindToClose(function()
			ProfileStore.IsClosing = true
			task.wait() -- Mock shutdown delay
		end)

		return -- Don't wait for profiles to properly save in mock mode so studio could end the simulation faster

	end

	game:BindToClose(function()

		ProfileStore.IsClosing = true

		-- Release all active profiles:
		-- (Clone AutoSaveList to a new table because AutoSaveList changes when profiles are released)

		local on_close_save_job_count = 0
		local active_profiles = {}
		for index, profile in ipairs(AutoSaveList) do
			active_profiles[index] = profile
		end

		-- Release the profiles; Releasing profiles can trigger listeners that release other profiles, so check active state:
		for _, profile in ipairs(active_profiles) do
			if profile:IsActive() == true then
				on_close_save_job_count = on_close_save_job_count + 1
				task.spawn(function() -- Save profile on new thread
					SaveProfileAsync(profile, true, nil, "Shutdown")
					on_close_save_job_count = on_close_save_job_count - 1
				end)
			end
		end

		-- Yield until all active profile jobs are finished:
		while on_close_save_job_count > 0 or ActiveProfileLoadJobs > 0 or ActiveProfileSaveJobs > 0 do
			task.wait()
		end

		return -- We're done!

	end)

end)

return ProfileStore