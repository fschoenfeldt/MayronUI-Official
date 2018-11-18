-- Setup -------------------------------
local addOnName, namespace = ...;
namespace.bars = {};

local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents();
local appearance;

-- Objects -----------------------------

local Engine = obj:Import("MayronUI.Engine");
local CastBarClass = Engine:CreateClass("CastBar", "Framework.System.FrameWrapper");

-- Register Modules --------------------

local CastBarsModuleClass = MayronUI:RegisterModule("CastBars");

-- Load Database Defaults --------------

db:AddToDefaults("profile.castbars", {
    templateCastBar = {
        enabled = true,
        width = 250,
        height = 27,
        showIcon = false,
        unlocked = false, -- make movable
        frameStrata = "MEDIUM",
        frameLevel = 10
    },
    appearance = {
        texture = "MUI_StatusBar",
        border = "Skinner",
        borderSize = 1,
        inset = 1,
        colors = {
            finished = {r = 0.8, g = 0.8, b = 0.8, a = 0.7},
            interrupted = {r = 1, g = 0, b = 0, a = 0.7},
            border = {r = 0, g = 0, b = 0, a = 1},
            backdrop = {r = 0, g = 0, b = 0, a = 0.6},
            latency = {r = 1, g = 1, b = 1, a = 0.6},
        },
    },
    player = {
        anchorToSUF = true,
        showLatency = true,
    },
    target = {
        anchorToSUF = true,
    },
    focus = {},
    mirror = {
        position = {
            point = "TOP",
            relativeFrame = "UIParent",
            relativePoint = "TOP",
            x = 0, 
            y = -200,
        },
    }
});

-------------------
-- Channel Ticks
-------------------
local Ticks = {};

function Ticks:Create(data)
    local tick = data.frame.statusbar:CreateTexture(nil, "OVERLAY");
    tick:SetSize(26, data.frame.statusbar:GetHeight() + 20);
    data.ticks = data.ticks or {};
    tk.table.insert(data.ticks, tick);
    tick:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark");
    tick:SetVertexColor(1, 1, 1);
    tick:SetBlendMode("ADD");
    return tick;
end

Ticks.data = {
    -- DRUID
    [(GetSpellInfo(740)) or "_"] = 4, -- Tranquility

    -- MAGE
    [(GetSpellInfo(5143)) or "_"] = 5, -- Arcane Missiles
    [(GetSpellInfo(12051)) or "_"] = 3, -- Evocation
    [(GetSpellInfo(205021)) or "_"] = 10, -- Ray of Frost

    -- MONK
    [(GetSpellInfo(117952)) or "_"] = 4, -- Crackling Jade Lightning
    [(GetSpellInfo(191837)) or "_"] = 3, -- Essence Font

    -- PRIEST
    [(GetSpellInfo(64843)) or "_"] = 4, -- Divine Hymn
    [(GetSpellInfo(15407)) or "_"] = 4, -- Mind Flay
    [(GetSpellInfo(47540)) or "_"] = 2, -- Penance
    [(GetSpellInfo(205065)) or "_"] = 4, -- Void Torrent

    -- WARLOCK
    [(GetSpellInfo(193440)) or "_"] = 3, -- Demonwrath
    [(GetSpellInfo(198590)) or "_"] = 6, -- Drain Soul
	[(GetSpellInfo(234153)) or "_"] = 4, -- Health Funnel
};

-- Events ---------------------
local Events = {};

function Events:MIRROR_TIMER_PAUSE(castBar, castBarData, pauseDuration)
    castBarData.paused = pauseDuration > 0;
    
    if (pauseDuration > 0) then
        castBarData.pauseDuration = pauseDuration;
    end
end

function Events:MIRROR_TIMER_START(castBar, castBarData, ...)
    local _, value, maxValue, step, pause, label = ...;

    castBarData.frame.statusbar:SetMinMaxValues(0, (maxValue / 1000));
    castBarData.frame.statusbar:SetValue((value / 1000));
    castBarData.paused = pause;
    castBarData.startTime = GetTime();
    castBarData.frame.name:SetText(label);

    local c = appearance.colors.normal;
    castBarData.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
    tk.UIFrameFadeIn(castBarData.frame, 0.1, castBarData.frame:GetAlpha(), 1);
end

function Events:MIRROR_TIMER_STOP(castBar, castBarData)
    castBarData.paused = 0;
    castBarData.pauseDuration = nil;
    castBarData.fadingOut = true;
    castBarData.startTime = nil;

    tk.UIFrameFadeOut(castBarData.frame, 1, castBarData.frame:GetAlpha(), 0);
end

function Events:UNIT_SPELLCAST_INTERRUPTED(castBar, castBarData, ...)
    castBarData.frame.statusbar:SetValue(tk.select(2, castBarData.frame.statusbar:GetMinMaxValues()))
    castBar:StopCasting();
    
	local c = appearance.colors.interrupted;
    castBarData.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
end

function Events:UNIT_SPELLCAST_INTERRUPTIBLE(castBar, castBarData)
	local c = appearance.colors.normal;
    castBarData.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
end

function Events:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(castBar, castBarData)
	local c = appearance.colors.interrupted;
    castBarData.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
end

function Events:PLAYER_TARGET_CHANGED(castBar, castBarData)
	if (UnitExists(castBarData.unitID) and tk.select(1, UnitCastingInfo(castBarData.unitID))) then
        if (UnitName(castBarData.unitID) == castBarData.unitName) then return end
        
		castBar:StopCasting();
        castBar:StartCasting();
        
	elseif (castBarData.frame:GetAlpha() > 0) then
		castBar:StopCasting();
        castBarData.frame:SetAlpha(0);
        castBarData.frame:Hide();
	end
end

function Events:UNIT_SPELLCAST_DELAYED(castBar, castBarData)
    local endTime = tk.select(6, UnitCastingInfo(castBarData.unitID));
    
	if (not endTime or not castBarData.startTime) then
		self:UNIT_SPELLCAST_INTERRUPTED(castBar, castBarData);
		return;
    end
    
	endTime = endTime / 1000;
    castBarData.frame.statusbar:SetMinMaxValues(0, endTime - castBarData.startTime);
end

function Events:UNIT_SPELLCAST_START(castBar, castBarData, unitID)
	if (unitID ~= castBarData.unitID) then return end
	castBar:StartCasting();
end

function Events:UNIT_SPELLCAST_CHANNEL_START(castBar, castBarData, unitID)
    if (unitID ~= castBarData.unitID) then return end
    castBar:StartCasting(true);
end

function Events:UNIT_SPELLCAST_CHANNEL_STOP(castBar, castBarData)
    castBarData.frame.statusbar:SetValue(tk.select(2, castBarData.frame.statusbar:GetMinMaxValues()));

    if (castBarData.frame.statusbar:GetValue() > 0.1) then
        self:UNIT_SPELLCAST_CHANNEL_UPDATE(castBar, castBarData);
    else
        castBar:StopCasting();
    end
end

function Events:UNIT_SPELLCAST_CHANNEL_UPDATE(castBar, castBarData)
    local endTime = tk.select(6, UnitChannelInfo(castBarData.unitID));

    if (not endTime or not castBarData.startTime) then
        castBar:StopCasting();

        local c = appearance.colors.interrupted;
        castBarData.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);

        return;
    end

    endTime = endTime / 1000;
    castBarData.frame.statusbar:SetMinMaxValues(0, endTime - castBarData.startTime);
end

function Events:UNIT_SPELLCAST_SENT(castBar, castBarData)
    castBarData.latency = GetTime();
end

-- CastBarClass ----------------------

function CastBarClass:__Construct(data, sv, unitID, bar)
    data.sv = sv;
    data.unitID = unitID;
    data.frame = bar;
    
    self.tempData = data;    
end

function CastBarClass:Update(data)
    if (not data.startTime) then
        if (data.frame:GetAlpha() == 0) then
            data.fadingOut = nil;
        end
        return;
    end

    if (data.unitID == "mirror") then
        if (not data.paused or data.paused == 0) then
            for i = 1, MIRRORTIMER_NUMTIMERS do
                local _, _, _, step, _, label = GetMirrorTimerInfo(i);

                if (label == data.frame.name:GetText()) then
                    local value = MirrorTimer1StatusBar:GetValue();
                    local duration = tk.string.format("%.1f", value);

                    if (tk.tonumber(duration) > 60) then
                        duration = tk.date("%M:%S", duration);
                    end

                    data.frame.duration:SetText(duration);
                    data.frame.statusbar:SetValue(value);
                    return;
                end
            end
        end
    else
        if (data.startTime and not self:IsFinished()) then
            local difference = GetTime() - data.startTime;

            if (data.channelling or data.unitID == "mirror") then
                data.frame.statusbar:SetValue(data.totalTime - difference);
            else
                data.frame.statusbar:SetValue(difference);
            end

            local duration = data.totalTime - difference;

            if (duration < 0) then 
                duration = 0; 
            end

            duration = tk.string.format("%.1f", duration);

            if (tk.tonumber(duration) > 60) then
                duration = tk.date("%M:%S", duration);
            end

            data.frame.duration:SetText(duration);

        elseif (data.unitID ~= "mirror") then
            self:StopCasting();
        else
            self:MIRROR_TIMER_STOP();
        end
    end
end

function CastBarClass:SetTicks(data, numTicks)
    if (data.ticks) then
        for _, tick in tk.ipairs(data.ticks) do
            tick:Hide();
        end
    end

    if (numTicks == 0) then 
        return; 
    end

    local width = data.frame.statusbar:GetWidth();

    for i = 1, numTicks do
        if (i < numTicks) then
            local tick = (data.ticks and data.ticks[i]) or Ticks:Create(data);
            tick:ClearAllPoints();
            tick:SetPoint("CENTER", data.frame.statusbar, "LEFT", width * (i / numTicks), 0);
            tick:Show();
        end
    end
end

function CastBarClass:IsFinished(data)
    local value = data.frame.statusbar:GetValue();
    local maxValue = tk.select(2, data.frame.statusbar:GetMinMaxValues());

    if (data.channelling) then
        return value <= 0; -- max value for channelling is reversed
    end

	return value >= maxValue;
end

function CastBarClass:UpdateAppearance(data)
    data.frame.statusbar:SetStatusBarTexture(tk.Constants.LSM:Fetch("statusbar", appearance.texture));

    data.frame:SetSize(data.sv.width, data.sv.height);
    data.frame:SetFrameStrata(data.sv.frameStrata);
    data.frame:SetFrameLevel(data.sv.frameLevel);

    data.frame.statusbar:ClearAllPoints();
    data.frame.statusbar:SetPoint("TOPLEFT", appearance.inset, -appearance.inset);
    data.frame.statusbar:SetPoint("BOTTOMRIGHT", -appearance.inset, appearance.inset);

    if (not data.bg) then
        data.bg = tk.CreateFrame("Frame", nil, data.frame);
        data.bg:SetPoint("TOPLEFT", data.frame, "TOPLEFT", -1, 1);
        data.bg:SetPoint("BOTTOMRIGHT", data.frame, "BOTTOMRIGHT", 1, -1);
        data.bg:SetFrameLevel(5);
    end

    data.backdrop = data.backdrop or {};
    data.backdrop.edgeFile = tk.Constants.LSM:Fetch("border", appearance.border);
    data.backdrop.edgeSize = appearance.borderSize;
    data.frame:SetBackdrop(data.backdrop);

    data.frame:SetBackdropBorderColor(appearance.colors.border.r, appearance.colors.border.g,
        appearance.colors.border.b, appearance.colors.border.a);

    if (not data.latency_bar and data.unitID == "player" and data.sv.showLatency) then
        data.latency_bar = data.frame.statusbar:CreateTexture(nil, "BACKGROUND");
        data.latency_bar:SetColorTexture(
            appearance.colors.latency.r,
            appearance.colors.latency.g,
            appearance.colors.latency.b,
            appearance.colors.latency.a
        );
        data.latency_bar:SetPoint("TOPRIGHT");
        data.latency_bar:SetPoint("BOTTOMRIGHT");
    end
    
    if (not data.icon and data.sv.showIcon) then
        data.square = tk.CreateFrame("Frame", nil, data.frame);
        data.square:SetPoint("TOPRIGHT", data.frame, "TOPLEFT", -2, 0);
        data.square:SetPoint("BOTTOMRIGHT", data.frame, "BOTTOMLEFT", -2, 0);
        data.square:SetBackdrop({
            edgeFile = tk.Constants.LSM:Fetch("border", "Skinner"),
            edgeSize = 1,
        });
        data.square:SetBackdropBorderColor(0, 0, 0);
        data.icon = data.square:CreateTexture(nil, "ARTWORK");
        data.icon:SetPoint("TOPLEFT", data.square, "TOPLEFT", 1, -1);
        data.icon:SetPoint("BOTTOMRIGHT", data.square, "BOTTOMRIGHT", -1, 1);
    end

    if (data.square) then
        if (data.sv.anchorToSUF) then
            local unitframe = tk._G["SUFUnit"..data.unitID:lower()];
            local sufAnchor = unitframe and unitframe.portrait;
            data.square:SetWidth(sufAnchor:GetHeight() + 2);
        else
            data.square:SetWidth(data.sv.height);
        end
    end
end

function CastBarClass:StopCasting(data)
	if (not data.fadingOut) then
		data.startTime = nil;
		data.unitName = nil;
		local c = appearance.colors.finished;
		data.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
		data.fadingOut = true;
        if (not data.frame.unlocked) then
            tk.UIFrameFadeOut(data.frame, 1, 1, 0);
        else
            data.frame.statusbar:SetValue(0);
            data.frame.name:SetText("");
            data.frame.duration:SetText("");
        end
	end
end

function CastBarClass:StartCasting(data, channelling)
    local func = channelling and UnitChannelInfo or UnitCastingInfo;
    local name, _, texture, startTime, endTime, _, _, notInterruptible = func(data.unitID);
    
	if (not startTime) then
		if (data.frame:GetAlpha() > 0 and not data.fadingOut) then
			self:StopCasting();
		end
		return;
    end
	
	startTime = startTime / 1000; -- To make the same as GetTime() format
	endTime = endTime / 1000; -- To make the same as GetTime() format

	data.frame.statusbar:SetMinMaxValues(0, endTime - startTime); -- 0 to n seconds
	data.frame.name:SetText(name);
	
	if (data.icon) then
		data.icon:SetTexture(texture);
		data.icon:SetTexCoord(0.13, 0.87, 0.13, 0.87);
	end
	
	if (notInterruptible) then
		local c = appearance.colors.interrupted;
		data.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
	else
		local c = appearance.colors.normal;
		data.frame.statusbar:SetStatusBarColor(c.r, c.g, c.b, c.a);
    end

    if (data.latency_bar and data.latency and data.latency > 0) then
        if (data.sv.showLatency) then
            local width = tk.math.floor(data.frame.statusbar:GetWidth() + 0.5);
            local percent = (GetTime() - data.latency);
            local latency_width = (width * percent);

            if (latency_width >= width) then latency_width = 1; end
            if (latency_width == 0) then latency_width = 1; end
            if (latency_width == 1) then
                data.latency_bar:Hide();
            else
                data.latency_bar:Show();
            end
            data.latency_bar:SetWidth(latency_width);
        else
            data.latency_bar:Hide();
        end
    end

    -- ticks:
    if (channelling) then
        self:SetTicks(Ticks.data[name] or 0);
        data.frame.statusbar:SetValue(endTime - startTime);
    else
        self:SetTicks(0);
        data.frame.statusbar:SetValue(0);
    end

    tk.UIFrameFadeIn(data.frame, 0.1, 0, 1);
	
	data.fadingOut = nil;
    data.channelling = channelling;
	data.unitName = UnitName(data.unitID);
	data.startTime = startTime; -- makes OnUpdate start casting the bar
	data.totalTime = endTime - startTime;
end

function CastBarClass:PositionCastBar(data)
    data.frame:ClearAllPoints();

    local unitframe = _G[ string.format("SUFUnit%s", data.unitID:lower()) ];    
    local anchorToSUF = IsAddOnLoaded("ShadowedUnitFrames") and data.sv.anchorToSUF;
    local sufAnchor = unitframe and unitframe.portrait;

    if (not (anchorToSUF and sufAnchor)) then
        -- manual position...
        data.sv.anchorToSUF = false;
        
        if (not data.sv.position) then
            data.frame:SetPoint("CENTER");
        else
            local point = data.sv.position.point;
            local relativeFrame = data.sv.position.relativeFrame; 
            local relativePoint = data.sv.position.relativePoint;
            local x, y = data.sv.position.x, data.sv.position.y;

            if (point and relativeFrame and relativePoint and x and y) then
                data.frame:SetPoint(point, _G[relativeFrame], relativePoint, x, y);
            else
                data.frame:SetPoint("CENTER");
            end
        end
    else
        -- anchor to ShadowedUnitFrames
        data.frame:SetPoint("TOPLEFT", sufAnchor, "TOPLEFT", -1, 1);
        data.frame:SetPoint("BOTTOMRIGHT", sufAnchor, "BOTTOMRIGHT", 1, -1);
    end
end

-- CastBarsModuleClass -----------------------

local function CreateCastBar(unitID, sv)
    local globalName = string.format("MUI_%sCastBar", unitID:gsub("^%l", string.upper));
	local bar = CreateFrame("Frame", globalName, UIParent);
    bar:SetAlpha(0);

    bar.statusbar = CreateFrame("StatusBar", nil, bar);
    bar.statusbar:SetValue(0);

    bar.statusbar.bg = tk:SetBackground(bar.statusbar, 
        appearance.colors.backdrop.r, 
        appearance.colors.backdrop.g,
        appearance.colors.backdrop.b, 
        appearance.colors.backdrop.a);        

    if (unitID == "mirror") then
        MirrorTimer1:SetAlpha(0);
        MirrorTimer1.SetAlpha = tk.Constants.DUMMY_FUNC;
    elseif (unitID == "player") then
        CastingBarFrame:UnregisterAllEvents();
        CastingBarFrame:Hide();
    end

	bar.name = bar.statusbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	bar.name:SetPoint("LEFT", 4, 0);
	bar.name:SetWidth(150);
	bar.name:SetWordWrap(false);
	bar.name:SetJustifyH("LEFT");

	bar.duration = bar.statusbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	bar.duration:SetPoint("RIGHT", -4, 0);
	bar.duration:SetJustifyH("RIGHT");

    if (unitID == "mirror") then
        bar:RegisterEvent("MIRROR_TIMER_PAUSE");
        bar:RegisterEvent("MIRROR_TIMER_START");
        bar:RegisterEvent("MIRROR_TIMER_STOP");
    else
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_START", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unitID);
        bar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unitID);

        if (unitID == "target") then
            bar:RegisterEvent("PLAYER_TARGET_CHANGED");
        elseif (unitID == "focus") then
            bar:RegisterEvent("PLAYER_FOCUS_CHANGED");
        elseif (unitID == "player") then
            bar:RegisterEvent("UNIT_SPELLCAST_SENT");
        end
    end

    bar.enabled = sv.enabled;

    local castBar = CastBarClass(sv, unitID, bar);
    local castBarData = castBar.tempData;
    castBar.tempData = nil;

    castBar:UpdateAppearance();
    castBar:PositionCastBar();

    local totalElapsed = 0;
    bar:SetScript("OnUpdate", function(_, elapsed)
        if (bar:GetAlpha() > 0) then
            totalElapsed = totalElapsed + elapsed;

            if (bar.enabled and totalElapsed > 0.01) then 
                castBar:Update(elapsed);
                totalElapsed = 0;
            end
        end
    end);

    bar:SetScript("OnEvent", function(self, eventName, ...)
        if (not sv.enabled) then 
            return; 
        end

		if (eventName == "PLAYER_FOCUS_CHANGED") then
			eventName = "PLAYER_TARGET_CHANGED";
        end
        
        Events[eventName](Events, castBar, castBarData, ...);
    end);

    return castBar;
end

function CastBarsModuleClass:OnInitialize(data)
    data.sv = db.profile.castbars;
    appearance = data.sv.appearance;

    local r, g, b = tk:GetThemeColor();
    db:AddToDefaults("profile.castbars.appearance.colors.normal", {
        r = r, 
        g = g, 
        b = b, 
        a = 0.7
    });

	for _, name in ipairs({"player", "target", "focus", "mirror"}) do
        local sv = data.sv[name];
        sv:SetParent(data.sv.templateCastBar);

		if (sv.enabled) then
            namespace.bars[name] = CreateCastBar(name, sv);
		end
	end
end

function CastBarsModuleClass:OnConfigUpdate(data, list, value)
    local key = list:PopFront();

    if (key == "profile" and list:PopFront() == "castbars") then
        key = list:PopFront();

        if (CastBars_Module.bars[key]) then
            local castbar = CastBars_Module.bars[key];
            key = list:PopFront();

            if (key == "anchorToSUF" or key == "position") then
                castbar:PositionCastBar();
            elseif (key == "frameLevel") then
                castbar:SetFrameLevel(value);
            elseif (key == "frameStrata") then
                castbar:SetFrameStrata(value);
            elseif (key == "width") then
                castbar:SetWidth(value);
            elseif (key == "height") then
                castbar:SetHeight(value);
            elseif (key == "showIcon") then
                local data = CastBar.Static:GetData(castbar);

                if (data.square) then
                    data.square:SetShown(value);
                end

                if (value) then
                    castbar:UpdateAppearance();
                end
            elseif (key == "enabled") then
                castbar:SetShown(value);
            end

        elseif (key == "appearance") then
            key = list:PopFront();

            if (key:find("border") or key == "texture" or key == "inset") then
                for _, bar in tk.pairs(CastBars_Module.bars) do
                    bar:UpdateAppearance();
                end

            elseif (key == "colors") then
                key = list:PopFront();

                if (key == "border") then
                    for _, bar in tk.pairs(CastBars_Module.bars) do
                        bar = bar:GetFrame();
                        bar:SetBackdropBorderColor(value.r, value.g, value.b, value.a);
                    end

                elseif (key == "backdrop") then
                    for _, bar in tk.pairs(CastBars_Module.bars) do
                        bar = bar:GetFrame().statusbar;
                        bar.bg:SetColorTexture(value.r, value.g, value.b, value.a);
                    end

                elseif (key == "latency") then
                    local castbar = CastBars_Module.bars["player"];

                    if (castbar) then
                        local data = CastBar.Static:GetData(castbar);

                        if (data.latency_bar) then
                            data.latency_bar:SetColorTexture(value.r, value.g, value.b, value.a);
                        end
                    end
                end
            end
        else
            if (key and (key == "player" or key == "target" or key == "focus" or key == "mirror")) then
                if (list:PopFront() == "enabled") then
                    local bar = CastBars_Module.bars[key];

                    if (bar) then
                        bar:GetFrame().enabled = value;
                    elseif (value) then
                        CastBars_Module.bars[key] = CreateCastBar(key, CastBars_Module.sv[key]);
                    end
                end
            end
        end
    end
end