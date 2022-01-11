--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	DB.addHandler("charsheet.*.inventorylist.*.isidentified", "onUpdate", onItemIDChanged);
	DB.addHandler("charsheet.*.inventorylist.*.carried", "onUpdate", onItemCarriedChanged);
end

function onItemCarriedChanged(nodeItemID)
	local nodeItem = nodeItemID.getChild("..");
	local nodeChar = nodeItemID.getChild("....");
	local nCarried = DB.getValue(nodeItem, 'carried');

	if ItemManager2.isArmor(nodeItem) then
		addToArmorDB(nodeItem, nCarried);
	elseif ItemManager2.isWeapon(nodeItem) then
		addToWeaponDB(nodeItem, nCarried);
	end
end

--
--	Armor inventory management
--

function addToArmorDB(nodeItem, nCarried)
	-- Parameter validation
	if not ItemManager2.isArmor(nodeItem) then
		return;
	end

	local nodeChar = nodeItem.getChild("...");
	local nodeArmors = nodeChar.createChild("armorlist");
	if not nodeArmors then
		return;
	end

	-- Is this armor being equipped
	local nEquipped = 0;
	if nCarried == 2 then
		nEquipped = 1;
	end

	-- Check we don't have this armor item already listed
	local sPath = nodeItem.getPath();
	for _,vArmor in pairs(DB.getChildren(nodeChar, "armorlist")) do
		local _,sRecord = DB.getValue(vArmor, "shortcut", "", "");
		if sRecord == sPath then
			DB.setValue(vArmor, "equipped", "number", nEquipped);
			return;
		end
	end

	-- Determine identification
	local nItemID = 0;
	if LibraryData.getIDState("item", nodeItem, true) then
		nItemID = 1;
	end

	-- Grab some information from the source node to populate the new armor entries
	local sName;
	if nItemID == 1 then
		sName = DB.getValue(nodeItem, "name", "");
	else
		sName = DB.getValue(nodeItem, "nonid_name", "");
		if sName == "" then
			sName = Interface.getString("item_unidentified");
		end
		sName = "** " .. sName .. " **";
	end

	-- Which locations does this armor cover?
	local sLocationsCovered = DB.getValue(nodeItem, "cover");
	sLocationsCovered = sLocationsCovered:gsub("&", ","):lower();
	sLocationsCovered = sLocationsCovered:gsub("%s+", "");

	local nHead, nLeftArm, nLeftArm, nLeftLeg, nRightLeg, nTorso = 0,0,0,0,0,0;

	-- iterate through the locations
	local aLocations = StringManager.split(sLocationsCovered, ",");

	local nodeArmor = nodeArmors.createChild();
	if nodeArmor then
		DB.setValue(nodeArmor, "isidentified", "number", nItemID);
		DB.setValue(nodeArmor, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName());

		Debug.console(aLocations[i]);

		for i = 1, #aLocations do
			if aLocations[i] == "head" then
				nHead = 1;
			end
			if aLocations[i] == "torso" then
				nTorso = 1;
			end
			if aLocations[i] == "legs" then
				nLeftLeg = 1;
				nRightLeg = 1;
			end
			if aLocations[i] == "arms" then
				nLeftArm = 1;
				nRightArm = 1;
			end
			if aLocations[i] == "leftleg" then
				nLeftLeg = 1;
			end
			if aLocations[i] == "rightleg" then
				nRightLeg = 1;
			end
			if aLocations[i] == "leftarm" then
				nLeftArm = 1;
			end
			if aLocations[i] == "rightarm" then
				nRightArm = 1;
			end
		end

		DB.setValue(nodeArmor, "name", "string", sName);
		DB.setValue(nodeArmor, "equipped", "number", nEquipped);
		DB.setValue(nodeArmor, "ev", "number", DB.getValue(nodeItem, "encumbrancevalue"));
		DB.setValue(nodeArmor, "enhancementmax", "number", DB.getValue(nodeItem, "armorenhancement"));
		DB.setValue(nodeArmor, "sp", "number", DB.getValue(nodeItem, "stoppingpower"));
		DB.setValue(nodeArmor, "spmax", "number", DB.getValue(nodeItem, "stoppingpower"));
		DB.setValue(nodeArmor, "effects", "string", DB.getValue(nodeItem, "effect"));
		DB.setValue(nodeArmor, "location_head", "number", nHead);
		DB.setValue(nodeArmor, "location_leftarm", "number", nLeftArm);
		DB.setValue(nodeArmor, "location_rightarm", "number", nRightArm);
		DB.setValue(nodeArmor, "location_leftleg", "number", nLeftLeg);
		DB.setValue(nodeArmor, "location_rightleg", "number", nRightLeg);
		DB.setValue(nodeArmor, "location_torso", "number", nTorso);
	end
end


--
--	Weapon inventory management
--

function addToWeaponDB(nodeItem)
	-- Parameter validation
	if not ItemManager2.isWeapon(nodeItem) then
		return;
	end

	-- Get the weapon list we are going to add to
	local nodeChar = nodeItem.getChild("...");
	local nodeWeapons = nodeChar.createChild("weaponlist");
	if not nodeWeapons then
		return;
	end

	-- Check we don't have this armor item already listed
	local sPath = nodeItem.getPath();
	for _,vArmor in pairs(DB.getChildren(nodeChar, "weaponlist")) do
		local _,sRecord = DB.getValue(vArmor, "shortcut", "", "");
		if sRecord == sPath then
			DB.setValue(vArmor, "equipped", "number", nEquipped);
			return;
		end
	end

	-- Determine identification
	local nItemID = 0;
	if LibraryData.getIDState("item", nodeItem, true) then
		nItemID = 1;
	end

	-- Grab some information from the source node to populate the new weapon entries
	local sName;
	if nItemID == 1 then
		sName = DB.getValue(nodeItem, "name", "");
	else
		sName = DB.getValue(nodeItem, "nonid_name", "");
		if sName == "" then
			sName = Interface.getString("item_unidentified");
		end
		sName = "** " .. sName .. " **";
	end

	-- Lastly depending on the type of weapon, we have to set the attackskill and attackstat
	local sAttackSkill, sAttackStat = "";

	sWeaponType = DB.getValue(nodeItem, "type", ""):lower();
	sWeaponSubType = DB.getValue(nodeItem, "subtype", ""):lower();

	local sAttackSkill = DataCommon.aWeaponSkillsBySubType[sWeaponSubType]:lower();
	local sAttackStat = DataCommon.aWeaponStatsBySubType[sWeaponSubType]:lower();

	-- Effects
	local aEffects = getEffects(nodeItem);

	local nodeWeapon = nodeWeapons.createChild();
	if nodeWeapon then
		DB.setValue(nodeWeapon, "isidentified", "number", nItemID);
		DB.setValue(nodeWeapon, "shortcut", "windowreference", "item", "....inventorylist." .. nodeItem.getName());

		DB.setValue(nodeWeapon, "name", "string", sName);
		DB.setValue(nodeWeapon, "attackskill", "string", sAttackSkill);
		DB.setValue(nodeWeapon, "attackstat", "string", sAttackStat);
		DB.setValue(nodeWeapon, "bleeding_amount", "number", 0);
		DB.setValue(nodeWeapon, "concealment", "string", DB.getValue(nodeItem, "concealment"));

		nodeWeapon.createChild("enhancementlist");
		DB.setValue(nodeWeapon, "enhancementmax", "number", DB.getValue(nodeItem, "enhancements"));
		DB.setValue(nodeWeapon, "focus_amount", "number", 0);
		DB.setValue(nodeWeapon, "maxammo", "number", 0);
		DB.setValue(nodeWeapon, "rangeincrement", "number", 0);
		DB.setValue(nodeWeapon, "reliability", "number", DB.getValue(nodeItem, "reliability"));
		DB.setValue(nodeWeapon, "reliabilitymax", "number", DB.getValue(nodeItem, "reliability"));
		DB.setValue(nodeWeapon, "stun_amount", "number", 0);
		DB.setValue(nodeWeapon, "weapon_accuracy", "number", DB.getValue(nodeItem, "weaponaccuracy"));
		DB.setValue(nodeWeapon, "type", "number", 0);

		for _,v in pairs(aEffects) do
			if v:match('|') then
				local aEffectsDetails = StringManager.split(v,"|");
				DB.setValue(nodeWeapon, "weffect_" .. aEffectsDetails[1] .. "_use", "number", 1);
				if aEffectsDetails[1] == "bleeding" then
					DB.setValue(nodeWeapon, "bleeding_amount", "number", aEffectsDetails[2]);
				elseif aEffectsDetails[1] == "focus" then
					DB.setValue(nodeWeapon, "focus_amount", "number", aEffectsDetails[2]);
				elseif aEffectsDetails[1] == "stun" then
					DB.setValue(nodeWeapon, "stun_amount", "number", aEffectsDetails[2]);
				end
			else
				DB.setValue(nodeWeapon, "weffect_" .. v .. "_use", "number", 1);
			end
		end

		nodeWeaponDamageList = nodeWeapon.createChild("damagelist");
		nodeWeaponDamage = nodeWeaponDamageList.createChild();

		local aDamageDice, nDamageBonus = StringManager.convertStringToDice(DB.getValue(nodeItem, "damage"));

		DB.setValue(nodeWeaponDamage, "bonus", "number", nDamageBonus);
		DB.setValue(nodeWeaponDamage, "dice", "dice", aDamageDice);
		DB.setValue(nodeWeaponDamage, "type", "string", DB.getValue(nodeItem, "damagetype"));

		local aEffects = getEffects(nodeItem);

	end


	-- <bleeding_amount type="number">25</bleeding_amount>
	-- <focus_amount type="number">3</focus_amount>
	-- <stun_amount type="number">2</stun_amount>
	-- <attackstat type="string">dexterity</attackstat>
	-- <bleeding_amount type="number">0</bleeding_amount>
	-- <concealment type="string">Large</concealment>
	-- <damagelist>
	-- 	<id-00001>
	-- 		<bonus type="number">2</bonus>
	-- 		<dice type="dice">2d6</dice>
	-- 		<type type="string">S/P</type>
	-- 	</id-00001>
	-- </damagelist>
	-- <enhancementlist />
	-- <enhancementmax type="number">0</enhancementmax>
	-- <focus_amount type="number">0</focus_amount>
	-- <maxammo type="number">0</maxammo>
	-- <name type="string">Arming Sword</name>
	-- <rangeincrement type="number">0</rangeincrement>
	-- <reliability type="number">15</reliability>
	-- <reliabilitymax type="number">0</reliabilitymax>
	-- <stun_amount type="number">0</stun_amount>
	-- <type type="number">0</type>
	-- <weapon_accuracy type="number">0</weapon_accuracy>
	-- <weffect_ablating_use type="number">0</weffect_ablating_use>
	-- <weffect_armorpiercing_use type="number">0</weffect_armorpiercing_use>
	-- <weffect_balanced_use type="number">0</weffect_balanced_use>
	-- <weffect_bleeding_use type="number">0</weffect_bleeding_use>
	-- <weffect_brawling_use type="number">0</weffect_brawling_use>
	-- <weffect_concealment_use type="number">0</weffect_concealment_use>
	-- <weffect_focus_use type="number">0</weffect_focus_use>
	-- <weffect_grappling_use type="number">0</weffect_grappling_use>
	-- <weffect_greaterfocus_use type="number">0</weffect_greaterfocus_use>
	-- <weffect_improvedarmorpiercing_use type="number">0</weffect_improvedarmorpiercing_use>
	-- <weffect_longreach_use type="number">0</weffect_longreach_use>
	-- <weffect_meteorite_use type="number">0</weffect_meteorite_use>
	-- <weffect_nonethal_use type="number">0</weffect_nonethal_use>
	-- <weffect_slowreload_use type="number">0</weffect_slowreload_use>
	-- <weffect_stun_use type="number">0</weffect_stun_use>




end

function removeFromWeaponDB(nodeItem)
	if not nodeItem then
		return false;
	end

	-- Check to see if any of the weapon nodes linked to this item node should be deleted
	local sItemNode = nodeItem.getPath();
	local sItemNode2 = "....inventorylist." .. nodeItem.getName();
	local bFound = false;
	for _,v in pairs(DB.getChildren(nodeItem, "...weaponlist")) do
		local sClass, sRecord = DB.getValue(v, "shortcut", "", "");
		if sRecord == sItemNode or sRecord == sItemNode2 then
			bFound = true;
			v.delete();
		end
	end

	return bFound;
end

--
--	Identification handling
--

function onItemIDChanged(nodeItemID)
	local nodeItem = nodeItemID.getChild("..");
	local nodeChar = nodeItemID.getChild("....");

	local sPath = nodeItem.getPath();
	for _,vWeapon in pairs(DB.getChildren(nodeChar, "weaponlist")) do
		local _,sRecord = DB.getValue(vWeapon, "shortcut", "", "");
		if sRecord == sPath then
			checkWeaponIDChange(vWeapon);
		end
	end
end

function checkWeaponIDChange(nodeWeapon)
	local _,sRecord = DB.getValue(nodeWeapon, "shortcut", "", "");
	if sRecord == "" then
		return;
	end
	local nodeItem = DB.findNode(sRecord);
	if not nodeItem then
		return;
	end

	local bItemID = LibraryData.getIDState("item", DB.findNode(sRecord), true);
	local bWeaponID = (DB.getValue(nodeWeapon, "isidentified", 1) == 1);
	if bItemID == bWeaponID then
		return;
	end

	local sName;
	if bItemID then
		sName = DB.getValue(nodeItem, "name", "");
	else
		sName = DB.getValue(nodeItem, "nonid_name", "");
		if sName == "" then
			sName = Interface.getString("item_unidentified");
		end
		sName = "** " .. sName .. " **";
	end
	DB.setValue(nodeWeapon, "name", "string", sName);

	-- local nBonus = 0;
	-- if bItemID then
	-- 	DB.setValue(nodeWeapon, "attackbonus", "number", DB.getValue(nodeWeapon, "attackbonus", 0) + DB.getValue(nodeItem, "bonus", 0));
	-- 	local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeWeapon, "damagelist"));
	-- 	if #aDamageNodes > 0 then
	-- 		DB.setValue(aDamageNodes[1], "bonus", "number", DB.getValue(aDamageNodes[1], "bonus", 0) + DB.getValue(nodeItem, "bonus", 0));
	-- 	end
	-- else
	-- 	DB.setValue(nodeWeapon, "attackbonus", "number", DB.getValue(nodeWeapon, "attackbonus", 0) - DB.getValue(nodeItem, "bonus", 0));
	-- 	local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeWeapon, "damagelist"));
	-- 	if #aDamageNodes > 0 then
	-- 		DB.setValue(aDamageNodes[1], "bonus", "number", DB.getValue(aDamageNodes[1], "bonus", 0) - DB.getValue(nodeItem, "bonus", 0));
	-- 	end
	-- end

	if bItemID then
		DB.setValue(nodeWeapon, "isidentified", "number", 1);
	else
		DB.setValue(nodeWeapon, "isidentified", "number", 0);
	end
end

--
-- Effects
--

function getEffects(v)
	local sEffects;
	local sVarType = type(v);
	if sVarType == "databasenode" then
		sEffects = DB.getValue(v, "effect", "");
	elseif sVarType == "string" then
		sEffects = v;
	else
		return nil;
	end

	local aEffects = StringManager.split(sEffects:lower(), "\n", true);
	local aEffectsToUpdate = {};
	local sEffectAmount = "";

	for _,s in ipairs(aEffects) do
		if s:match("%b()") then
			sEffect, sEffectAmount = s:match("(.-) %((.-)%)");
			sEffectAmount = sEffectAmount:gsub('%%','');
		else
			sEffect = s;
		end

		for _,v in pairs(DataCommon.aWeaponEffects) do
			if v == sEffect then
				sEffect = sEffect:gsub("-","");
				table.insert(aEffectsToUpdate, sEffect.. "|" ..sEffectAmount);
			end
		end
	end

	return aEffectsToUpdate
end

function checkEffect(v, sTargetEffect)
	local sEffects;
	local sVarType = type(v);
	if sVarType == "databasenode" then
		sEffects = DB.getValue(v, "properties", "");
	elseif sVarType == "string" then
		sEffects = v;
	else
		return nil;
	end

	local tProps = StringManager.split(sEffects:lower(), ",", true);
	for _,s in ipairs(tProps) do
		if s:match("^" .. sTargetEffect) then
			return true;
		end
	end
	return false;
end

function getEffect(v, sTargetPattern)
	local sEffects;
	local sVarType = type(v);
	if sVarType == "databasenode" then
		sEffects = DB.getValue(v, "effect", "");
	elseif sVarType == "string" then
		sEffects = v;
	else
		return nil;
	end

	local tProps = StringManager.split(sEffects:lower(), ",", true);
	for _,s in ipairs(tProps) do
		local result = s:match("^" .. sTargetPattern);
		if result then
			return result;
		end
	end
	return nil;
end

function getEffectNumber(v, sTargetPattern)
	local sProp = getEffect(v, sTargetPattern);
	if sProp then
		return tonumber(sProp) or 0;
	end
	return nil;
end

