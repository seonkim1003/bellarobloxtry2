--!strict
--[[
	Client networking boundary for the frozen remote contract.
	Supports Agent 1 GameRemotes and scaffold Remotes folder names.
]]

local SharedAccess = require(script.Parent:WaitForChild("SharedAccess"))

export type SignalHandler = (payload: any) -> ()

local RemoteBoundary = {}
RemoteBoundary.__index = RemoteBoundary

export type RemoteBoundary = typeof(setmetatable(
	{} :: {
		_folder: Folder?,
		_handlers: { [string]: { SignalHandler } },
		_received: { [string]: boolean },
		_connections: { RBXScriptConnection },
		_contentConfig: any,
	},
	RemoteBoundary
))

function RemoteBoundary.new(): RemoteBoundary
	local contentConfig = SharedAccess.requireContentConfig()
	local self = setmetatable({
		_folder = nil :: Folder?,
		_handlers = {},
		_received = {},
		_connections = {},
		_contentConfig = contentConfig,
	}, RemoteBoundary)

	for _, signalName in contentConfig.serverSignals do
		self._handlers[signalName] = {}
		self._received[signalName] = false
	end

	return self
end

function RemoteBoundary:_getRemote(name: string): RemoteEvent?
	local folder = self._folder
	if folder == nil then
		return nil
	end
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

function RemoteBoundary:start(timeoutSeconds: number?): boolean
	local folder = SharedAccess.getRemotesFolder(timeoutSeconds or 10)
	if folder == nil then
		warn("[Content] Remotes folder not found yet (expected GameRemotes or Remotes)")
		return false
	end

	self._folder = folder
	local contentConfig = self._contentConfig

	for _, signalName in contentConfig.serverSignals do
		local remote = folder:WaitForChild(signalName, 5)
		if remote and remote:IsA("RemoteEvent") then
			local connection = remote.OnClientEvent:Connect(function(payload: any)
				self._received[signalName] = true
				local handlers = self._handlers[signalName]
				if handlers then
					for _, handler in handlers do
						handler(payload)
					end
				end
			end)
			table.insert(self._connections, connection)
		else
			warn(`[Content] Missing server signal remote: {signalName}`)
		end
	end

	for _, requestName in contentConfig.clientRequests do
		if folder:FindFirstChild(requestName) == nil then
			warn(`[Content] Missing client request remote: {requestName}`)
		end
	end

	return true
end

function RemoteBoundary:on(signalName: string, handler: SignalHandler)
	local list = self._handlers[signalName]
	if list == nil then
		self._handlers[signalName] = { handler }
	else
		table.insert(list, handler)
	end
end

function RemoteBoundary:request(requestName: string, payload: any?)
	local contentConfig = self._contentConfig
	local allowed = false
	for _, name in contentConfig.clientRequests do
		if name == requestName then
			allowed = true
			break
		end
	end
	if not allowed then
		warn(`[Content] Refusing unknown client request: {requestName}`)
		return
	end

	local remote = self:_getRemote(requestName)
	if remote == nil then
		warn(`[Content] Cannot fire {requestName}; remote missing`)
		return
	end
	remote:FireServer(payload)
end

function RemoteBoundary:getReceivedSignalNames(): { string }
	local names = {}
	for _, signalName in self._contentConfig.serverSignals do
		if self._received[signalName] then
			table.insert(names, signalName)
		end
	end
	return names
end

function RemoteBoundary:hasReceivedAllSignals(): boolean
	for _, signalName in self._contentConfig.serverSignals do
		if not self._received[signalName] then
			return false
		end
	end
	return true
end

function RemoteBoundary:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return RemoteBoundary
