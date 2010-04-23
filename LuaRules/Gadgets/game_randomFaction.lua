function gadget:GetInfo()
	return {
		name      = "Spring: 1944 Random faction",
		desc      = "Sets player to random faction (if GM mode is off)",
		author    = "Nemo",
		date      = "17 May 2009",
		license   = "Public domain",
		layer     = -10,
		enabled   = true  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then return end


function gadget:GameStart()
	--Make a global list of the side for each team, because with random faction
	--it is not trivial to find out the side of a team using Spring's API.
	GG.teamSide = {}
	for _,t in ipairs(Spring.GetTeamList()) do
		local _,_,_,_,side = Spring.GetTeamInfo(t)
		GG.teamSide[t] = side
	end

	--If GM is disabled, replace GM unit with a random HQ, and update GG.teamSide.
	local modOptions = Spring.GetModOptions()
	if (modOptions.gm_team_enable == "0") then
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local udid = Spring.GetUnitDefID(unitID)
			local ud = UnitDefs[udid]
			if (ud.customParams.gm) then
				local x,y,z = Spring.GetUnitPosition(unitID)
				local teamID = Spring.GetUnitTeam(unitID)
				local randomComm = math.random(1,4)
				local sideName, startUnit = Spring.GetSideData(randomComm)
				Spring.CreateUnit(startUnit, x, y, z, 0, teamID)
				GG.teamSide[teamID] = sideName
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end
end
