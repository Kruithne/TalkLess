--[[
	TalkLess (C) Kruithne <kruithne@gmail.com>
	Licensed under GNU General Public Licence version 3.
	
	https://github.com/Kruithne/TalkLess

	TalkLess.lua - Core add-on core/functions.
]]

local eventFrame = CreateFrame("FRAME");

--[[
	Interface/AddOns/Blizzard_TalkingHeadUI/Blizzard_TalkingHeadUI.lua
	WOW-21996patch7.0.3_Beta

	Q: Why are we implementing like this, rather than just hooking?
	A: Rather than giving this function parameters, Blizzard make a call to C_TalkingHead.GetCurrentLineInfo inside
	the function, and the results we need are stored locally. Calling the function again does not work as expected
	and in some cases, will cause a critical client error, crashing to desktop.

	This is not an ideal solution, but it seems more sensible then storing the spoken strings in a hash table. While
	Lua does match strings fast, the amount of strings we will end up storing after some use in the wild will amount
	to something silly.
]]--
local function HACK_TalkingHeadFrame_PlayCurrent()
	local frame = TalkingHeadFrame;
	local model = frame.MainFrame.Model;
	
	if (frame.finishTimer) then
		frame.finishTimer:Cancel();
		frame.finishTimer = nil;
	end

	if (frame.voHandle) then
		StopSound(frame.voHandle);
		frame.voHandle = nil;
	end
	
	local currentDisplayInfo = model:GetDisplayInfo();
	local displayInfo, cameraID, vo, duration, lineNumber, numLines, name, text, isNewTalkingHead = C_TalkingHead.GetCurrentLineInfo();

	if TalkLessData[vo] then
		-- We've already heard this line before.
		local info = ChatTypeInfo["MONSTER_SAY"];
		DEFAULT_CHAT_FRAME:AddMessage(string.format(CHAT_MONSTER_SAY_GET, name) .. text, info.r, info.g, info.b);
		return;
	else
		-- New line, flag it as heard.
		TalkLessData[vo] = true;
	end

	local textFormatted = string.format(text);
	if (displayInfo and displayInfo ~= 0) then
		frame:Show();
		if (currentDisplayInfo ~= displayInfo) then
			model.uiCameraID = cameraID;
			model:SetDisplayInfo(displayInfo);
		else
			if (model.uiCameraID ~= cameraID) then
				model.uiCameraID = cameraID;
				Model_ApplyUICamera(model, model.uiCameraID);
			end

			TalkingHeadFrame_SetupAnimations(model);
		end
		
		if (isNewTalkingHead) then
			TalkingHeadFrame_Reset(frame, textFormatted, name);
			TalkingHeadFrame_FadeinFrames();
		else
			if (name ~= frame.NameFrame.Name:GetText()) then
				-- Fade out the old name and fade in the new name
				frame.NameFrame.Fadeout:Play();
				C_Timer.After(0.25, function()
					frame.NameFrame.Name:SetText(name);
				end);
				C_Timer.After(0.5, function()
					frame.NameFrame.Fadein:Play();
				end);
				
				frame.MainFrame.TalkingHeadsInAnim:Play();
			end

			if ( textFormatted ~= frame.TextFrame.Text:GetText() ) then
				-- Fade out the old text and fade in the new text
				frame.TextFrame.Fadeout:Play();
				C_Timer.After(0.25, function()
					frame.TextFrame.Text:SetText(textFormatted);
				end);
				C_Timer.After(0.5, function()
					frame.TextFrame.Fadein:Play();
				end);
			end
		end
		
		
		local success, voHandle = PlaySoundKitID(vo, "Talking Head", true, true);
		if (success) then
			frame.voHandle = voHandle;
		end
	end
end

local function OnLoad()
	if not TalkLessData then
		TalkLessData = {};
	end

	TalkingHeadFrame_PlayCurrent = HACK_TalkingHeadFrame_PlayCurrent;

	eventFrame:SetScript("OnEvent", nil);
	eventFrame:UnregisterEvent("ADDON_LOADED");
end

local function OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...;
		local ADDON_NAME = "TalkLess";
		local BLIZZ_ADDON_NAME = "Blizzard_TalkingHeadUI";

		if addonName == ADDON_NAME then
			if IsAddOnLoaded(BLIZZ_ADDON_NAME) then
				OnLoad();
			end
		elseif addonName == BLIZZ_ADDON_NAME then
			if IsAddOnLoaded(ADDON_NAME) then
				OnLoad();
			end
		end
	end
end

eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:SetScript("OnEvent", OnEvent);