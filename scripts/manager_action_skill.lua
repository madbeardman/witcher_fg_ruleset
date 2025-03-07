-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	ActionsManager.registerModHandler("skill", onSkillModifier);
	ActionsManager.registerResultHandler("skill", onSkillRoll);
end

function performRoll(draginfo, rActor, sSkillName, nSkillMod, sSkillStat)
   --print("performRoll");
   --Debug.console(draginfo);
   --Debug.console(rActor);
   --Debug.console(sSkillName);
   --Debug.console(nSkillMod);
   --Debug.console(sSkillStat);

	local rRoll = getRoll(rActor, sSkillName, nSkillMod, sSkillStat);
	
	if User.isHost() and CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		rRoll.bSecret = true;
	end
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function getRoll(rActor, sSkillName, nSkillMod, sSkillStat)
	Debug.console("Rolling for skill '"..sSkillName.."'");
	--Debug.chat("---- getRoll");
    --Debug.chat(rActor);
    --Debug.chat(sSkillName);
    --Debug.chat(nSkillMod);
    --Debug.chat(sSkillStat);
    --Debug.chat(sExtra);

	local rRoll = {};
	rRoll.sType = "skill";
	rRoll.aDice = { "d10" };
	rRoll.nMod = nSkillMod or 0;
	rRoll.sDesc = "[SKILL] " .. sSkillName;
	if sExtra then
		rRoll.sDesc = rRoll.sDesc .. " " .. sExtra;
	end

	-- Check if roll is a potential defense action (dodge/escape or athletics)
	rRoll.sIsDefense = "false";
	
	local s = string.lower(sSkillName);
	-- Debug.chat(s);
	s = string.gsub(s, "%s+", "") -- remove spaces
	-- Debug.chat(s);
	s = string.gsub(s, "/", "") -- remove /
	-- Debug.chat(s);
	if s=="dodgeescape" or s=="athletics" then
		Debug.console("Rolling "..s.." : set skill roll as defense.");
		rRoll.sIsDefense = "true";
	end

	-- Add parameters for exploding dice management
	rRoll.sExplodeMode  = "none";	-- initial roll, will be "fumble" or "crit" on reroll
	rRoll.nTotalExplodeValue = 0; 	-- cumulative value of exploding rolls
	rRoll.sStoredDice = "";			-- store all dice for final display message
	
	-- Substract equipped armor part EV
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if (string.lower(sSkillStat) == "reflex") or (string.lower(sSkillStat)=="dexterity") then
		local nTotalEV = CharManager.getTotalEV(nodeActor);
		if (nTotalEV > 0) then
			rRoll.nMod = rRoll.nMod - nTotalEV;
			--rRoll.sDesc = rRoll.sDesc .. "["..Interface.getString("rolldescription_totalev").." -"..nTotalEV.."]"
		end
	end

	if sSkillStat then
		local sAbilityEffect = sSkillStat;
		if sAbilityEffect then
			rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
		end
	end
	
	-- check effect and condition affecting Stat and skill
	local nCondMod, nCondDesc = CharManager.getConditionRollModifier(nodeActor, sSkillName, sSkillStat, rRoll.sIsDefense=="true");
	rRoll.sDesc = rRoll.sDesc .. nCondDesc;
	rRoll.nMod = rRoll.nMod + nCondMod;

	return rRoll;
end

-- Modifier handler : additional modifiers to apply to the roll
function onSkillModifier(rSource, rTarget, rRoll)
    --print("onSkillModifier");
    --Debug.console(rSource);
    --Debug.console(rTarget);
    --Debug.console(rRoll);
    --Debug.console(rRoll.sDesc);

	local aAddDesc = {};
	local nAddMod = 0;
	
	-- Check modifiers

	local bLightLevelModifier = "daylight";
	if ModifierStack.getModifierKey("LGT_BRI") then
		bLightLevelModifier = "bright";
	elseif ModifierStack.getModifierKey("LGT_DIM") then
		bLightLevelModifier = "dim";
	elseif ModifierStack.getModifierKey("LGT_DRK") then
		bLightLevelModifier = "darkness";
	end
	
	if string.match(rRoll.sDesc, "Awareness") == "Awareness" then
   	if bLightLevelModifier == "bright" then
   		table.insert(aAddDesc, "["..Interface.getString("modifier_label_light_bright").." -3]");
   		nAddMod = nAddMod - 3;
   	elseif bLightLevelModifier == "dim" then
   		table.insert(aAddDesc, "["..Interface.getString("modifier_label_light_dim").." -2]");
   		nAddMod = nAddMod - 2;
   	elseif bLightLevelModifier == "darkness" then
   		table.insert(aAddDesc, "["..Interface.getString("modifier_label_light_dark").." -4]");
   		nAddMod = nAddMod - 4;
   	end
    end
	
	if rSource then
		-- TODO : Get condition modifiers
	end
	
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
	
	rRoll.nMod = rRoll.nMod + nAddMod;
end

function onSkillRoll(rSource, rTarget, rRoll)
    -- print("onSkillRoll");
    -- Debug.console(rSource);
    -- Debug.console(rTarget);
    -- Debug.console(rRoll);

	local bDisplayFinalMessage = true;
	
	local rActor = ActorManager.resolveActor(DB.findNode(rSource.sCreatureNode));

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
			-- rRoll.nMod = tonumber(rRoll.nMod) - 1;
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
    	-- Debug.console(rSource);
    	-- Debug.console(rRoll);
    	local rMessage = ActionsManager.createActionMessage(rActor, rRoll);
    	rMessage.text = string.gsub(rMessage.text, " %[MOD:[^]]*%]", "");
    	-- Debug.console(rMessage);
    	-- update rMessage in case of fumble
    	if (bFumble) then
    		rMessage.text = rMessage.text .. "\n[FUMBLE (".. rRoll.nTotalExplodeValue ..") : ";
    		-- Debug.chat(rRoll.nTotalExplodeValue);
    		-- check nTotalExplodeValue and attack type to resolve fumble
    		local nFumbleValue = tonumber(rRoll.nTotalExplodeValue);
    		if ( nFumbleValue <= 5) then
    			rMessage.text = rMessage.text .. Interface.getString("fumble_none");
    		end
   		    
    		rMessage.text = rMessage.text .. "]";
    	end
    	
        -- Display the message in chat.
		Comm.deliverChatMessage(rMessage);
		
		local nDefValue = ActionsManager.total(rRoll);
		Debug.console("Skill result = "..nDefValue);
		Debug.console(rRoll.sIsDefense);
		if rRoll.sIsDefense == "true" then
			Debug.console("This was a defensive roll, call for resolution.");
			---- Resolve Defense
			if nDefValue < 0 then
				nDefValue = 0;
			end
			
			CombatManager2.resolvePendingAttack(rSource, nDefValue, "");
		end
		
    end
end

-- PRIVATE METHODS --------------------------------------------------------

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
	
	local aNewDice = {};
	for i, k in pairs (rRoll.aDice) do -- FGU compatibility : change loops "for i=1, # ..." in "for i,k in pairs ..."
		local aDiceTmp = rRoll.aDice[i];
		for j,l in pairs (aDiceTmp) do -- FGU compatibility : change loops "for j=1, # ..." in "for j,l in pairs ..."
			local aDieTmp = aDiceTmp[j];
			
			if j ~= "expr" then -- FGU compatibility : don't propagate "expr" in aDice array
				-- 10 is always rerolled => set it green
				if tonumber(aDieTmp.result)==10 then
					aDieTmp.type="g10";
				end
				
				if i==1 and tonumber(aDieTmp.result)==1 then
					-- first die was a 1 => fumble, set ir red
					bFumble = true;
					aDieTmp.type="r10";
					-- Reset dice value
					aDieTmp.result = 0;
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
