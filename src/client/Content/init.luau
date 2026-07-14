--!strict

local PlaceholderCatalog = require(script:WaitForChild("PlaceholderCatalog"))
local PlaceholderMount = require(script:WaitForChild("PlaceholderMount"))
local Tagging = require(script:WaitForChild("Tagging"))
local TowerBuilder = require(script:WaitForChild("TowerBuilder"))
local AssetFallback = require(script:WaitForChild("AssetFallback"))
local MarketplaceIntegration = require(script:WaitForChild("MarketplaceIntegration"))

return table.freeze({
	PlaceholderCatalog = PlaceholderCatalog,
	PlaceholderMount = PlaceholderMount,
	Tagging = Tagging,
	TowerBuilder = TowerBuilder,
	AssetFallback = AssetFallback,
	MarketplaceIntegration = MarketplaceIntegration,
})
