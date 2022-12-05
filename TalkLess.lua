--[[
	TalkLess (C) Kruithne <kruithne@gmail.com>
	Licensed under GNU General Public Licence version 3.
	
	https://github.com/Kruithne/TalkLess

	TalkLess.lua - Core add-on core/functions.
]]

local eventFrame = CreateFrame("FRAME");

--[[
	Function sourced from:
	Interface/FrameXML/TalkingHeadUI.lua
	Version 10.0.0 (46313)

	Q: Why are we implementing like this, rather than just hooking?
	A: Rather than giving this function parameters, Blizzard make a call to C_TalkingHead.GetCurrentLineInfo inside
	the function, and the results we need are stored locally. Calling the function again does not work as expected
	and in some cases, will cause a critical client error, crashing to desktop.

	This is not an ideal solution, but it seems more sensible then storing the spoken strings in a hash table. While
	Lua does match strings fast, the amount of strings we will end up storing after some use in the wild will amount
	to something silly.
]]--

-- Need to steal these as well due to scoping
local talkingHeadTextureKitRegionFormatStrings = {
	["TextBackground"] = "%s-TextBackground",
	["Portrait"] = "%s-PortraitFrame",
}
local talkingHeadDefaultAtlases = {
	["TextBackground"] = "TalkingHeads-TextBackground",
	["Portrait"] = "TalkingHeads-Alliance-PortraitFrame",
}
local talkingHeadFontColor = {
	["TalkingHeads-Horde"] = {Name = CreateColor(0.28, 0.02, 0.02), Text = CreateColor(0.0, 0.0, 0.0), Shadow = CreateColor(0.0, 0.0, 0.0, 0.0)},
	["TalkingHeads-Alliance"] = {Name = CreateColor(0.02, 0.17, 0.33), Text = CreateColor(0.0, 0.0, 0.0), Shadow = CreateColor(0.0, 0.0, 0.0, 0.0)},
	["TalkingHeads-Neutral"] = {Name = CreateColor(0.33, 0.16, 0.02), Text = CreateColor(0.0, 0.0, 0.0), Shadow = CreateColor(0.0, 0.0, 0.0, 0.0)},
	["Normal"] = {Name = CreateColor(1, 0.82, 0.02), Text = CreateColor(1, 1, 1), Shadow = CreateColor(0.0, 0.0, 0.0, 1.0)},
}

local function TalkLess_Override(self)
	self.isPlaying = true;

	local model = self.MainFrame.Model;

	if( self.finishTimer ) then
		self.finishTimer:Cancel();
		self.finishTimer = nil;
	end
	if ( self.voHandle ) then
		StopSound(self.voHandle);
		self.voHandle = nil;
	end

	local currentDisplayInfo = model:GetDisplayInfo();
	local displayInfo, cameraID, vo, duration, lineNumber, numLines, name, text, isNewTalkingHead, textureKit = C_TalkingHead.GetCurrentLineInfo();

	-- TalkLess change begin
	if TalkLessData[vo] then
		-- We've already heard this line before.
		return;
	else
		-- New line, flag it as heard.
		TalkLessData[vo] = true;
	end
	-- TalkLess change end

	local textFormatted = string.format(text);
	if ( displayInfo and displayInfo ~= 0 ) then
		if textureKit then
			SetupTextureKitOnRegions(textureKit, self.BackgroundFrame, talkingHeadTextureKitRegionFormatStrings, TextureKitConstants.DoNotSetVisibility, TextureKitConstants.UseAtlasSize);
			SetupTextureKitOnRegions(textureKit, self.PortraitFrame, talkingHeadTextureKitRegionFormatStrings, TextureKitConstants.DoNotSetVisibility, TextureKitConstants.UseAtlasSize);
		else
			SetupAtlasesOnRegions(self.BackgroundFrame, talkingHeadDefaultAtlases, true);
			SetupAtlasesOnRegions(self.PortraitFrame, talkingHeadDefaultAtlases, true);
			textureKit = "Normal";
		end
		local nameColor = talkingHeadFontColor[textureKit].Name;
		local textColor = talkingHeadFontColor[textureKit].Text;
		local shadowColor = talkingHeadFontColor[textureKit].Shadow;
		self.NameFrame.Name:SetTextColor(nameColor:GetRGB());
		self.NameFrame.Name:SetShadowColor(shadowColor:GetRGBA());
		self.TextFrame.Text:SetTextColor(textColor:GetRGB());
		self.TextFrame.Text:SetShadowColor(shadowColor:GetRGBA());
		local wasShown = self:IsShown();
		self:UpdateShownState();
		if ( currentDisplayInfo ~= displayInfo ) then
			model.uiCameraID = cameraID;
			model:SetDisplayInfo(displayInfo);
		else
			if ( model.uiCameraID ~= cameraID ) then
				model.uiCameraID = cameraID;
				Model_ApplyUICamera(model, model.uiCameraID);
			end
			model:SetupAnimations();
		end

		if ( isNewTalkingHead or not wasShown or self.isClosing ) then
			self:Reset(textFormatted, name);
			self:FadeinFrames();
		else
			if ( name ~= self.NameFrame.Name:GetText() ) then
				-- Fade out the old name and fade in the new name
				self.NameFrame.Fadeout:Play();
				C_Timer.After(0.25, function()
					self.NameFrame.Name:SetText(name);
				end);
				C_Timer.After(0.5, function()
					self.NameFrame.Fadein:Play();
				end);

				self.MainFrame.TalkingHeadsInAnim:Play();
			end

			if ( textFormatted ~= self.TextFrame.Text:GetText() ) then
				-- Fade out the old text and fade in the new text
				self.TextFrame.Fadeout:Play();
				C_Timer.After(0.25, function()
					self.TextFrame.Text:SetText(textFormatted);
				end);
				C_Timer.After(0.5, function()
					self.TextFrame.Fadein:Play();
				end);
			end
		end


		local success, voHandle = PlaySound(vo, "Talking Head", true, true);
		if ( success ) then
			self.voHandle = voHandle;
		end
	end
end

local function OnLoad()
	if not TalkLessData then
		TalkLessData = {};
	end

	TalkingHeadFrame.PlayCurrent = TalkLess_Override;

	eventFrame:SetScript("OnEvent", nil);
	eventFrame:UnregisterEvent("ADDON_LOADED");
end

local function OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...;
		local ADDON_NAME = "TalkLess";

		if addonName == ADDON_NAME then
			OnLoad();
		end
	end
end

eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:SetScript("OnEvent", OnEvent);