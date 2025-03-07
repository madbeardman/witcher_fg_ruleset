-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

--
-- Management for attack rolls
--

function onInit()
	-- Register modifier handler
	ActionsManager.registerModHandler("attack", onAttackModifier);
	
	-- Register the result handler - called after the dice have stopped rolling
	ActionsManager.registerResultHandler("attack", onAttackRoll);
	ActionsManager.registerResultHandler("attackreroll", onAttackRoll);
	ActionsManager.registerResultHandler("attacklocation", onAttackRoll);
	
end

-- method called by performRoll to initiate the roll object which will be given 
-- to high level ActionsManager to actually perform roll
-- params :
--	* rActor		: actor info retrieved by using ActorManager.resolveActor
--	* rWeapon		: weapon node
--	* sAttackType	: attack type (supported : "fast", "strong", "normal"). 
--					  Unknown or missing value will be trated like a "normal" attack
-- returns : 
--	* rRoll	: roll object
function getRoll(rActor, rWeapon, sAttackType)
	--Debug.chat("------- getRoll");
	--Debug.chat(rWeapon);
	
	-- Initialize a blank rRoll record
	local rRoll = {};
	
	-- Add the 4 minimum parameters needed:
	-- the action type.
	rRoll.sType = "attack";
	-- the dice to roll.
	rRoll.aDice = { "d10" };
	-- A modifier to apply to the roll, will be overloaded later.
	rRoll.nMod = 0;
	-- The description to show in the chat window, will be overloaded later
	rRoll.sDesc = "[Attack] ";
	
	rRoll.sTarget = "";

	-- Add parameters for exploding dice management
	rRoll.sExplodeMode  = "none";	-- initial roll, will be "fumble" or "crit" on reroll
	rRoll.nTotalExplodeValue = 0; 	-- cumulative value of exploding rolls
	rRoll.sStoredDice = "";			-- store all dice for final display message
	rRoll.sWeaponType = "" ; 		-- range, melee, unarmed (used for fumble resolution)
	
	-- Add parameters for damage location, may be modified by modifier (see OnAttackModifier) or by rolling location table
	rRoll.sWeaponEffects = "";
	rRoll.sDamageLocation = "";
	rRoll.sIsStrongAttack = "false";
	
	-- some special attack info must be stored to be used later
	rRoll.sSpecialAttack = "";

	if (rWeapon.range == "R") then
		rRoll.sWeaponType = "range";
	elseif (rWeapon.range == "M") then
		rRoll.sWeaponType = "melee";
	else
		rRoll.sWeaponType = "unarmed";
	end
	
	-- Look up actor / weapon specific information
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if nodeActor then
		local sRollDescription = "";
		local nRollMod = 0;
		
		if sAttackType == "fast" then
			sRollDescription = "["..Interface.getString("combat_fastattack_message").." "..rWeapon.label.."]";
		elseif sAttackType == "strong" then
			rRoll.sIsStrongAttack = "true";
			sRollDescription = "["..Interface.getString("combat_strongattack_message").." "..rWeapon.label.."]";
				
			-- no penalty if actor is a witcher from the wolf school
			if DB.getValue(nodeActor, "identite.profession", "") == Interface.getString("list_profession_witcher") and DB.getValue(nodeActor, "identite.witcher_school", "") == Interface.getString("list_witcherschool_wolf") then
				Debug.console("no penalty for strong attack as a witcher from the wolf school");
			else
				nRollMod = nRollMod - 3;
				sRollDescription = sRollDescription .. "[Strong -3]";
			end
		elseif sAttackType == "twinshot" then
			rRoll.sSpecialAttack = sAttackType;
			sRollDescription = "["..Interface.getString("combat_"..sAttackType.."_attack_message").." "..rWeapon.label.."]";
		else
			sRollDescription = "["..Interface.getString("combat_attack_message").." "..rWeapon.label.."]";
		end
		
		--effects and enhancement_list
		if rWeapon.effects then
			sRollDescription = sRollDescription .. "\n" .. rWeapon.effects;
		end

		-- stat modifier
		nRollMod = nRollMod + DB.getValue(nodeActor, "attributs."..rWeapon.stat, 0);
		-- sRollDescription = sRollDescription.."["..rWeapon.stat.." +"..DB.getValue(nodeActor, "attributs."..rWeapon.stat, 0).."]"
		Debug.console("["..rWeapon.stat.." +"..DB.getValue(nodeActor, "attributs."..rWeapon.stat, 0).."]")
		
		-- skill modifier
		if nodeActor.getParent().getName()=="charsheet" then
			-- PC case
			for _,v in pairs(nodeActor.getChild("skills.skillslist").getChildren()) do
				if (DB.getValue(v, "id", "") == rWeapon.skill) then
					nRollMod = nRollMod + DB.getValue(v, "skill_value", 0);
					-- sRollDescription = sRollDescription.."["..rWeapon.skill.." +"..DB.getValue(v, "skill_value", 0).."]"
					Debug.console("["..rWeapon.skill.." +"..DB.getValue(v, "skill_value", 0).."]")
					break;
				end
			end
		else
			-- NPC case
			nRollMod = nRollMod + CharManager.getNPCSkillValue(nodeActor, rWeapon.skill);
		end
		
		-- weapon accuracy modifier
		if (rWeapon.range ~= "U") then
			--Debug.chat("weapon accuracy modifier : "..rWeapon.weaponaccuracy);
			nRollMod = nRollMod + rWeapon.weaponaccuracy;
			--sRollDescription = sRollDescription.."[WA +"..rWeapon.weaponaccuracy.."]"
			Debug.console("[WA +"..rWeapon.weaponaccuracy.."]")
		end
		
		-- Substract equipped armor part EV
		local nTotalEV = CharManager.getTotalEV(nodeActor);
		if (nTotalEV > 0) then
			nRollMod = nRollMod - nTotalEV;
			--sRollDescription = sRollDescription.."["..Interface.getString("rolldescription_totalev").." -"..nTotalEV.."]"
			Debug.console("["..Interface.getString("rolldescription_totalev").." -"..nTotalEV.."]")
		end

		-- check effect and condition affecting Stat and skill
		local nCondMod, nCondDesc = CharManager.getConditionRollModifier(nodeActor, rWeapon.skill, rWeapon.stat, true);

		rRoll.sDesc = sRollDescription .. nCondDesc;
		rRoll.nMod = nRollMod + nCondMod;
	end
	
	return rRoll;
end

-- method called to initiate attack roll
-- params :
--	* draginfo		: info given when rolling from onDragStart event (nil if other event trigger the roll)
--	* rWeapon		: weapon node (actor node if unarmed attack)
--	* sAttackType	: attack type (supported : "fast", "strong", "normal", "punchfast", "punchstrong", "punchnormal", "kickfast", "kickstrong", "kicknormal"). 
--					  Unknown or missing value will be treated like a "normal" attack
function performRoll(draginfo, rWeapon, sAttackType)
	--Debug.chat("------- performRoll");
	--Debug.chat(rWeapon);
	-- retreive attack info and actor node 
	local rActor; 
	
	if (string.find(sAttackType, "punch") or string.find(sAttackType, "kick")) then
		-- unarmed attack
		rActor = rWeapon;
		rWeapon = {};
		rWeapon.range = "U";
		rWeapon.weaponaccuracy = 0;
		rWeapon.effects = "";
		rWeapon.type = "attack";	
		rWeapon.stat = "reflex";
		rWeapon.skill = "brawling";

		if (string.find(sAttackType, "punch"))then
			rWeapon.label = Interface.getString("char_label_punchlabel");
			rWeapon.type = string.gsub(sAttackType, "punch", "");
		elseif (string.find(sAttackType, "kick"))then
			rWeapon.label = Interface.getString("char_label_kicklabel");
			rWeapon.type = string.gsub(sAttackType, "kick", "");
		end
	else
		-- weapon attack
		rActor, rWeapon = CharManager.getWeaponAttackRollStructures(rWeapon);
	end
	
	-- get roll
	local rRoll = getRoll(rActor, rWeapon, sAttackType);
	
	-- roll it !
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

-- HANDLERS --------------------------------------------------------

-- callback for ActionsManager called after the dice have stopped rolling : resolve roll status and display chat message
function onAttackRoll(rSource, rTarget, rRoll)
	-- Debug.chat("------- onAttackRoll");
	-- Debug.chat(rRoll.sType);
	-- Debug.chat("--rSource : ");
	-- Debug.chat(rSource);
	-- Debug.chat("--rTarget : ");
	-- Debug.chat(rTarget);
	-- Debug.chat("--rRoll.sTarget : ");
	-- Debug.chat(rRoll.sTarget);
	-- Debug.chat("--rRoll : ");
	-- Debug.chat(rRoll);
	
	-- Debug.chat(rRoll.aDice[1].result);
	
	local bDisplayFinalMessage = true;
	
	local rActor = ActorManager.resolveActor(DB.findNode(rSource.sCreatureNode));
	
	if rTarget then
		-- Debug.chat("-- SET rRoll.sTarget : "..rTarget.sName);
		-- Debug.chat(rRoll.sDesc);
		_storeTarget(rRoll, rTarget);
		rRoll.sDesc = string.gsub(rRoll.sDesc, "%%s", rTarget.sName);
	else
		rRoll.sDesc = string.gsub(rRoll.sDesc, "%%s", "");
	end
	
	-- Check for reroll
	local nDiceResult = tonumber(rRoll.aDice[1].result);
	if (nDiceResult == 1) then
		-- Debug.chat("rolled a 1 => check case");
		if rRoll.sExplodeMode == "none" then
			-- roll 1 on first roll => fumble => reroll
			rRoll.sExplodeMode = "fumble";
			_storeDieForFinalMessage(rRoll);
			-- reinit rRoll dice
			rRoll.aDice = { "d10" };
			-- change roll type to avoid throwing to much dice if multi-targeting
			rRoll.sType = "attackreroll";
			-- reroll
			bDisplayFinalMessage = false;
			ActionsManager.performAction(nil, rActor, rRoll);
		else
			-- roll 1 on crit or fumble reroll
			_storeDieForFinalMessage(rRoll);
			rRoll.nTotalExplodeValue = tonumber(rRoll.nTotalExplodeValue) + tonumber(nDiceResult);
			bDisplayFinalMessage = true;
		end
	elseif (nDiceResult == 10) then
		-- Debug.chat("rolled a 10 => reroll");
		-- rolled a 10, reroll in any case
		if rRoll.sExplodeMode == "none" then
			rRoll.sExplodeMode = "crit";
		end
		rRoll.nTotalExplodeValue = tonumber(rRoll.nTotalExplodeValue) + nDiceResult;
		_storeDieForFinalMessage(rRoll);
		-- reinit rRoll dice
		rRoll.aDice = { "d10" };
		-- change roll type to avoid throwing to much dice if multi-targeting
		rRoll.sType = "attackreroll";
		-- reroll
		bDisplayFinalMessage = false;
		ActionsManager.performAction(nil, rActor, rRoll);
	else
		-- Debug.chat("rolled between 2 and 9");
		_storeDieForFinalMessage(rRoll);
		if rRoll.sExplodeMode ~= "none" then
			rRoll.nTotalExplodeValue = tonumber(rRoll.nTotalExplodeValue) + tonumber(nDiceResult);
		end
		bDisplayFinalMessage = true;
	end
	
	if bDisplayFinalMessage then
		local bFumble = _restoreDiceBeforeFinalMessage(rRoll);
		
		-- Create the base message based of the source and the final rRoll record (includes dice results).
		local rMessage = ActionsManager.createActionMessage(rActor, rRoll);
		
		-- update rMessage in case of fumble
		if (bFumble) then
			rMessage.text = rMessage.text .. "\n[FUMBLE (".. rRoll.nTotalExplodeValue ..") : ";
			--Debug.chat(rRoll.nTotalExplodeValue);
			-- check nTotalExplodeValue and attack type to resolve fumble
			local nFumbleValue = tonumber(rRoll.nTotalExplodeValue);
			if ( nFumbleValue <= 5) then
				rMessage.text = rMessage.text .. Interface.getString("fumble_none");
			end
				
			if (rRoll.sWeaponType == "range") then
				if (nFumbleValue >= 6 and nFumbleValue <= 7) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_range_6to7");
				elseif (nFumbleValue >= 8 and nFumbleValue <= 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_range_8to9");
				elseif (nFumbleValue > 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_range_over9");
				end
			elseif (rRoll.sWeaponType == "melee") then
				if (nFumbleValue == 6) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_melee_6");
				elseif (nFumbleValue == 7) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_melee_7");
				elseif (nFumbleValue == 8) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_melee_8");
				elseif (nFumbleValue == 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_melee_9");
				elseif (nFumbleValue > 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_range_over9");
				end
			elseif (rRoll.sWeaponType == "unarmed") then
				if (nFumbleValue == 6) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_unarmed_6");
				elseif (nFumbleValue == 7) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_unarmed_7");
				elseif (nFumbleValue == 8) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_unarmed_8");
				elseif (nFumbleValue == 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_unarmed_9");
				elseif (nFumbleValue > 9) then
					rMessage.text = rMessage.text .. Interface.getString("fumble_unarmed_over9");
				end
			end

			rMessage.text = rMessage.text .. "]";
		end
		
		-- Debug.chat(rMessage);
		
		-- add pending attack to queue
		local nAtkValue = ActionsManager.total(rRoll);
		if nAtkValue < 0 then
			nAtkValue=0;
		end

		if rRoll.sDamageLocation:match("^AIM_") then
			CombatManager2.notifyAttack(rSource, _getTargetFromRoll(rRoll), nAtkValue, rRoll.sDamageLocation, "true", rRoll.sIsStrongAttack, rRoll.sSpecialAttack, rRoll.sWeaponEffects);
		else
			CombatManager2.notifyAttack(rSource, _getTargetFromRoll(rRoll), nAtkValue, "", "false", rRoll.sIsStrongAttack, rRoll.sSpecialAttack, rRoll.sWeaponEffects);
		end
		
		-- Display the message in chat.
		Comm.deliverChatMessage(rMessage);
	end
end

-- Modifier handler : additional modifiers to apply to the roll
function onAttackModifier(rSource, rTarget, rRoll)
	Debug.console("--------------------------------------------");
	Debug.console("onAttackModifier");
	Debug.console("rTarget :");
	Debug.console(rTarget);

	local aAddDesc = {};
	local nAddMod = 0;
	
	-- Check modifiers
	local bFastDraw = ModifierStack.getModifierKey("ATT_FSTDRAW");
	local bStrongAttack = ModifierStack.getModifierKey("ATT_STRONG");
	local bTargetSilhouetted = ModifierStack.getModifierKey("ATT_SILTGT");
	local bAmbush = ModifierStack.getModifierKey("ATT_AMB");
	local bTargetPinned = ModifierStack.getModifierKey("ATT_TGTPINNED");
	local bTargetActiveDodge = ModifierStack.getModifierKey("ATT_TGTACTDODGE");
	local bMovingTarget = ModifierStack.getModifierKey("ATT_MOVTGT");
	local bRicochetShot = ModifierStack.getModifierKey("ATT_RIC");
	local bLightLevelModifier = "daylight";
	if ModifierStack.getModifierKey("LGT_BRI") then
		bLightLevelModifier = "bright";
	elseif ModifierStack.getModifierKey("LGT_DIM") then
		bLightLevelModifier = "dim";
	elseif ModifierStack.getModifierKey("LGT_DRK") then
		bLightLevelModifier = "darkness";
	end
	
	-- Aiming modifier. If aiming, this info must be stored for later damage resolution.
	local sAimingModifier = "";
	if ModifierStack.getModifierKey("AIM_HEAD") then
		rRoll.sDamageLocation = "AIM_HEAD";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimhead").. " -6]");
		nAddMod = nAddMod - 6;
	elseif ModifierStack.getModifierKey("AIM_TORSO") then
		rRoll.sDamageLocation = "AIM_TORSO";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimtorso").. " -1]");
		nAddMod = nAddMod - 1;
	elseif ModifierStack.getModifierKey("AIM_TAIL") then
		rRoll.sDamageLocation = "AIM_TAIL";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimtail").. " -2]");
		nAddMod = nAddMod - 2;
	elseif ModifierStack.getModifierKey("AIM_ARM") then
		rRoll.sDamageLocation = "AIM_ARM";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimarm").. " -3]");
		nAddMod = nAddMod - 3;
	elseif ModifierStack.getModifierKey("AIM_LEG") then
		rRoll.sDamageLocation = "AIM_LEG";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimleg").. " -2]");
		nAddMod = nAddMod - 2;
	elseif ModifierStack.getModifierKey("AIM_LIMB") then
		rRoll.sDamageLocation = "AIM_LIMB";
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_aiming").." : "..Interface.getString("modifier_label_aimlimb").. " -3]");
		nAddMod = nAddMod - 3;
	end
	
	-- if needed check range modifiers
	local sRangeModifier = "";
	if (rRoll.sWeaponType == "range") then
		if ModifierStack.getModifierKey("RNG_PB") then
			sRangeModifier = "pointblank";
		elseif ModifierStack.getModifierKey("RNG_MED") then
			sRangeModifier = "medium";
		elseif ModifierStack.getModifierKey("DMG_LNG") then
			sRangeModifier = "long";
		elseif ModifierStack.getModifierKey("DMG_EXT") then
			sRangeModifier = "extreme";
		end
	end
	
	
	if bFastDraw then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_fstdraw").." -3]");
		nAddMod = nAddMod - 3;
	end
	if bStrongAttack then
		if rRoll.sIsStrongAttack ~= "true" then
			table.insert(aAddDesc, "["..Interface.getString("modifier_label_atkstrong").." -3]");
			nAddMod = nAddMod - 3;
		end
	end
	if bTargetSilhouetted then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_silhouettedtarget").." +2]");
		nAddMod = nAddMod + 2;
	end
	if bAmbush then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_ambush").." +5]");
		nAddMod = nAddMod + 5;
	end
	if bTargetPinned then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_targetpinned").." +4]");
		nAddMod = nAddMod + 4;
	end
	if bTargetActiveDodge then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_targetactdodge").." -2]");
		nAddMod = nAddMod - 2;
	end
	if bMovingTarget then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_movtarget").." -3]");
		nAddMod = nAddMod - 3;
	end
	if bRicochetShot then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_ricshot").." -5]");
		nAddMod = nAddMod - 5;
	end
	if bLightLevelModifier == "bright" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_light_bright").." -3]");
		nAddMod = nAddMod - 3;
	elseif bLightLevelModifier == "darkness" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_light_dark").." -2]");
		nAddMod = nAddMod - 2;
	end
	if sRangeModifier == "pointblank" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_range_pointblank").." +5]");
		nAddMod = nAddMod + 5;
	elseif sRangeModifier == "medium" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_range_medium").." -2]");
		nAddMod = nAddMod - 2;
	elseif sRangeModifier == "long" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_range_long").." -4]");
		nAddMod = nAddMod - 4;
	elseif sRangeModifier == "extreme" then
		table.insert(aAddDesc, "["..Interface.getString("modifier_label_range_extreme").." -6]");
		nAddMod = nAddMod - 6;
	end
	
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
	
	rRoll.nMod = rRoll.nMod + nAddMod;
end


-- PRIVATE METHODS --------------------------------------------------------

-- store target object for attack roll
-- param :
--  * rTarget	: target of the attack
--	* rRoll		: roll to work on
function _storeTarget(rRoll, rTarget)
	if (rRoll.sTarget ~= "") then
		return;
	end

	rRoll.sTarget = Json.stringify(rTarget);
end

-- store target object for attack roll
-- param :
--	* rRoll		: roll to work on
-- returns :
--  * rTarget	: rTarget object
function _getTargetFromRoll(rRoll)
	if (rRoll.sTarget == "") then
		return nil;
	end

	return Json.parse(rRoll.sTarget);
end

-- store aDice in sStoredDice for final message
-- params :
--	* rRoll : roll to work on
function _storeDieForFinalMessage(rRoll)
	-- Debug.chat("--------------------- _storeDieForFinalMessage");
	-- Debug.chat(rRoll.sStoredDice);
	-- Debug.chat(rRoll.aDice);
	
	local aStoredDiceTmp = {};
	
	-- get previously stored dice if any
	if rRoll.sStoredDice ~= "" then
		aStoredDiceTmp = Json.parse(rRoll.sStoredDice);
	end
	
	-- store last die rolled
	table.insert(aStoredDiceTmp, rRoll.aDice);
	
	-- store for later
	rRoll.sStoredDice = Json.stringify(aStoredDiceTmp);
	
	-- Debug.chat("after :");
	-- Debug.chat(rRoll.sStoredDice);
end

-- restore sStoredDice in aDice before final message 
-- params :
--	* rRoll : roll to work on
-- returns : 
--	* bFumble : true if roll was a fumble false if not
function _restoreDiceBeforeFinalMessage(rRoll)
	-- Debug.chat("--------------------- _restoreDiceBeforeFinalMessage");
	-- Debug.chat(rRoll.sStoredDice);
	-- Debug.chat(rRoll.aDice);
	
	local bFumble = false;
	
	-- get previously stored dice
	local aStoredDiceTmp = Json.parse(rRoll.sStoredDice);
	
	-- restore in aDice;
	rRoll.aDice = aStoredDiceTmp;
	
	-- rearrange rRoll.aDice if needed (has reroll or location roll) as serialization seems to mess up array
	-- and color exploding dice
	-- if rRoll.sExplodeMode ~= "none" or rRoll.sIsLocationRoll=="true" then
	local aNewDice = {};
	
	for i, k in pairs (rRoll.aDice) do -- FGU compatibility : change loops "for i=1, # ..." in "for i,k in pairs ..."
		local aDiceTmp = rRoll.aDice[i];
		for j,l in pairs (aDiceTmp) do -- FGU compatibility : change loops "for j=1, # ..." in "for j,l in pairs ..."
			local aDieTmp = aDiceTmp[j];
			
			if j ~= "expr" then -- -- FGU compatibility : don't propagate "expr" in aDice array
				-- 10 is always rerolled => set it green
				if tonumber(aDieTmp.result)==10 then
					aDieTmp.type="g10";
				end
				
				if i==1 and tonumber(aDieTmp.result)==1 then
					-- first die was a 1 => fumble, set ir red
					bFumble = true;
					aDieTmp.type="r10";
				elseif bFumble then
					-- any result between 1 and 9 => get die as it is
					aDieTmp.result = 0-tonumber(aDieTmp.result)
				end
				
				table.insert(aNewDice, aDieTmp);
			end
		end
	end

	rRoll.aDice = aNewDice;
	
	-- Debug.chat("after :");
	-- Debug.chat(rRoll.aDice);
	
	return bFumble;
end

