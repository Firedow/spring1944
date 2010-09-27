function gadget:GetInfo()
	return {
		name		= "Infantry supply rules",
		desc		= "Infantry drain logistics when not in supply range and firing, firing rate bonus while in supply range, firing rate penalty when out of logistics",
		author	= "Nemo (B. Tyler), built on work by quantum and FLOZi",
		date		= "December 19, 2008",
		license = "CC attribution-noncommerical 3.0 or later",
		layer		= 0,
		enabled	= true	--	loaded by default?
	}
end

-- function localisations
-- Synced Read
local GetTeamResources		 	= Spring.GetTeamResources
local GetUnitAllyTeam		 	= Spring.GetUnitAllyTeam
local GetUnitDefID			 	= Spring.GetUnitDefID
local GetUnitSeparation			= Spring.GetUnitSeparation
local GetUnitTeam				= Spring.GetUnitTeam
local GetUnitIsStunned			= Spring.GetUnitIsStunned
--local GetUnitWeaponState		= Spring.GetUnitWeaponState
local ValidUnitID				= Spring.ValidUnitID
-- Synced Ctrl
local SetUnitWeaponState		= Spring.SetUnitWeaponState
--local UseUnitResource			= Spring.UseUnitResource

-- Constants
local GAIA_TEAM_ID				= Spring.GetGaiaTeamID()
local STALL_PENALTY				=	1.35 --1.35
local SUPPLY_BONUS				=	0.65 --65
-- Variables
local ammoSuppliers		=	{}
--local savedFrame		=	{}  -- infantry
local infantry 			= {}
local teams 			= Spring.GetTeamList()
local numTeams			= #teams

for i = 1, numTeams do
	infantry[teams[i]] = {}
end

local modOptions
if (Spring.GetModOptions) then
  modOptions = Spring.GetModOptions()
end

if gadgetHandler:IsSyncedCode() then
--	SYNCED

local function FindSupplier(unitID)
	local closestSupplier
	local closestDistance = math.huge
	local allyTeam = GetUnitAllyTeam(unitID)
	for supplierID in pairs(ammoSuppliers) do
		local supAllyTeam = GetUnitAllyTeam(supplierID)
		local supTeam = GetUnitTeam(supplierID)
		if allyTeam == supAllyTeam or supTeam == GAIA_TEAM_ID then
			local separation = GetUnitSeparation(unitID, supplierID, true)
			local supplierDefID = GetUnitDefID(supplierID)
			local supplyRange = tonumber(UnitDefs[supplierDefID].customParams.supplyrange)
			if separation < closestDistance and separation <= supplyRange then
				closestSupplier = supplierID
				closestDistance = separation
			end
		end
	end

	return closestSupplier
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitTeam = GetUnitTeam(unitID)
		local unitDefID = GetUnitDefID(unitID)
		local _,stunned,beingBuilt = GetUnitIsStunned(unitID)
		-- Unless the unit is being transported consider whether it is infantry.
		if (not stunned) then
			gadget:UnitCreated(unitID, unitDefID, unitTeam)
		end
		-- Unless the unit is being built consider whether it is an ammo supplier.
		if (not beingBuilt) then
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	local ud = UnitDefs[unitDefID]
	if ud.customParams.feartarget and not(ud.customParams.maxammo) and (ud.weapons[1]) then
		infantry[teamID][unitID] = true
	end
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
	local ud = UnitDefs[unitDefID]
	if ud.customParams.ammosupplier == '1' then
		ammoSuppliers[unitID] = true
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	infantry[teamID][unitID] = nil
	ammoSuppliers[unitID] = nil
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	gadget:UnitCreated(unitID, unitDefID, newTeam)
end

function gadget:UnitLoaded(unitID)
	-- If a unit is loaded into a transport and temporarily can't fire,
	-- behave as if it didn't exist until it gets unloaded again.
	local _, stunned = GetUnitIsStunned(unitID)
	if stunned then
		infantry[unitID] = nil
	end
end


-- If a unit is unloaded, do exactly the same as for newly created units.
gadget.UnitUnloaded = gadget.UnitCreated

function gadget:TeamDied(teamID)
	numTeams = numTeams - 1
	teams = Spring.GetTeamList()
	infantry[teamID] = nil
end

local function ProcessUnit(unitID, unitDefID, teamID, stalling)
	--local weaponCost = UnitDefs[unitDefID].customParams.weaponcost or 0.15
	local weaponID = UnitDefs[unitDefID].weapons[1].weaponDef
	local reload = WeaponDefs[weaponID].reload
	--local reloadFrameLength = (reload*30)

	if ValidUnitID(unitID) then
		-- Stalling. (stall penalty!)
		if (stalling) then
			SetUnitWeaponState(unitID, 0, {reloadTime = STALL_PENALTY*reload})
			return
		end

		-- In supply radius. (supply bonus!)
		local supplierID = FindSupplier(unitID)
		if supplierID then
			SetUnitWeaponState(unitID, 0, {reloadTime = SUPPLY_BONUS*reload})
			return
		end

		-- reset reload time otherwise
		SetUnitWeaponState(unitID, 0, {reloadTime = reload})
		
		-- Use resources if outside of supply
		--[[if (reloadFrame > savedFrame[unitID]) then
			savedFrame[unitID] = reloadFrame
			UseUnitResource(unitID, "e", weaponCost)
		end]]
	end
end

function gadget:GameFrame(n)
	for i = 1, numTeams do
		--Spring.Echo((n + (math.floor(32 / numTeams) * i)) % (32 * 3))
		--if n % (1*30) < 0.1 then
		if (n + (math.floor(32 / numTeams) * i)) % (32 * 3) < 0.1 then -- every 3 seconds with each team offset by 32 / numTeams * teamNum frames
			for unitID in pairs(infantry[teams[i]]) do
				local unitDefID = GetUnitDefID(unitID)
				--local teamID = GetUnitTeam(unitID)
				local teamID = teams[i]
				local logisticsLevel = GetTeamResources(teamID, "energy")
				local stalling = logisticsLevel < 5
				ProcessUnit(unitID, unitDefID, teamID, stalling)
			end
		end
	end
end

else
--	UNSYNCED
end
