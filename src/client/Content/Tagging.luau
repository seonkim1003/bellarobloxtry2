--!strict
--[[
	Applies frozen CollectionService tags and attributes to placeholder BaseParts.
]]

local CollectionService = game:GetService("CollectionService")

local Tagging = {}

function Tagging.applyTag(instance: Instance, tag: string)
	if not CollectionService:HasTag(instance, tag) then
		CollectionService:AddTag(instance, tag)
	end
end

function Tagging.applyAttributes(instance: Instance, attributes: { [string]: string | number })
	for key, value in attributes do
		instance:SetAttribute(key, value)
	end
end

function Tagging.applyMarker(
	instance: Instance,
	tag: string,
	attributes: { [string]: string | number }
)
	Tagging.applyTag(instance, tag)
	Tagging.applyAttributes(instance, attributes)
end

return Tagging
