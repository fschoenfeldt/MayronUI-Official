-- luacheck: ignore MayronUI self 143 631
local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents(); -- luacheck: ignore
local Private = {};

-- Register Modules ----------------------

local C_UnitPanels = MayronUI:RegisterModule("BottomUI_UnitPanels", "Unit Panels", true);

-- Load Database Defaults ----------------

db:AddToDefaults("profile.unitPanels", {
    enabled = true;
    grid = {
        anchorGrid = true; -- anchor Grid Frame to top of Unit Panels
        point = "BOTTOMRIGHT";
        anchorFrame = "Target";
        xOffset = -9;
        yOffset = 0;
        gridProfiles = {
            "MayronUIH"
        }
    };
    controlSUF = true;
    unitWidth = 325;
    height = 75;
    isSymmetric = true;
    alpha = 0.8;
    unitNames = {
        enabled = true;
        width = 235;
        height = 20;
        fontSize = 11;
        targetClassColored = true;
        xOffset = 24;
    };
    sufGradients = {
        enabled = true;
        height = 24;
        targetClassColored = true;
    };
});

-- UnitPanels Module -----------------

function C_UnitPanels:OnInitialize(data, buiContainer, subModules)
    data.buiContainer = buiContainer;
    data.ActionBarPanel = subModules.ActionBarPanel;
    data.settings = db.profile.unitPanels:GetUntrackedTable();

    data.updateFunctions = {
        enabled = function(value)
            data.settings.enabled = value;
            self:SetEnabled(value);
        end;

        grid = {
            anchorGrid = function(value)
                data.settings.grid.anchorGrid = value;
                if (not _G.IsAddOnLoaded("Grid")) then return; end

                if (not value) then
                    Private.AnchorGridFrame(data.settings.grid);
                    tk:HookFunc(_G.Grid.db, "SetProfile", Private.AnchorGridFrame, data.settings.grid);
                else
                    tk:UnhookFunc(_G.Grid.db, "SetProfile", Private.AnchorGridFrame);
                end
            end;
        };

        controlSUF = function(value)
            data.settings.controlSUF = value;
            if (not _G.IsAddOnLoaded("ShadowedUnitFrames")) then return; end

            if (not value) then
                local handler = em:FindHandlerByKey("DetachSufOnLogout");

                if (handler) then
                    handler:Destroy();
                    Private.DetachShadowedUnitFrames();
                    tk:UnhookFunc(_G.ShadowUF, "ProfilesChanged", Private.AttachShadowedUnitFrames);
                    tk:UnhookFunc("ReloadUI", Private.DetachShadowedUnitFrames);
                end
            else
                Private.AttachShadowedUnitFrames(data.right);
                tk:HookFunc(_G.ShadowUF, "ProfilesChanged", Private.AttachShadowedUnitFrames, data.right);
                tk:HookFunc("ReloadUI", Private.DetachShadowedUnitFrames);
                em:CreateEventHandler("PLAYER_LOGOUT", Private.DetachShadowedUnitFrames):SetKey("DetachSufOnLogout");
            end
        end;

        unitWidth = function(value)
            data.settings.unitWidth = value;

            data.left:SetSize(value, 180);
            data.right:SetSize(value, 180)
        end;

        height = function(value)
            data.settings.height = value;

            self:RepositionPanels();
        end;

        isSymmetric = function(value)
            data.settings.isSymmetric = value;
            self:SetSymmetrical(data.settings.isSymmetric);
        end;

        alpha = function(value)
            data.settings.alpha = value;

            if (data.left.noTargetBg) then
                -- if not symmetric then this will not exist
                data.left.noTargetBg:SetAlpha(data.settings.alpha);
            end

            data.left.bg:SetAlpha(data.settings.alpha);
            data.center.bg:SetAlpha(data.settings.alpha);
            data.right.bg:SetAlpha(data.settings.alpha);

            if (data.player and data.target) then
                data.player.bg:SetAlpha(data.settings.alpha);
                data.target.bg:SetAlpha(data.settings.alpha);
            end
        end;

        unitNames = {
            enabled = function(value)
                data.settings.unitNames.enabled = value;
                self:SetUnitNamesEnabled(value);
            end;

            width = function(value)
                data.settings.unitNames.width = value;
                data.player:SetSize(value, data.settings.unitNames.height);
                data.target:SetSize(value, data.settings.unitNames.height);
                data.player.text:SetWidth(value - 25);
                data.target.text:SetWidth(value - 25);
            end;

            height = function(value)
                data.settings.unitNames.height = value;
                data.player:SetSize(data.settings.unitNames.width, value);
                data.target:SetSize(data.settings.unitNames.width, value);
            end;

            fontSize = function(value)
                data.settings.unitNames.fontSize = value;
                local font = tk.Constants.LSM:Fetch("font", db.global.core.font);
                data.player.text:SetFont(font, value);
                data.target.text:SetFont(font, value);
            end;

            targetClassColored = function(value)
                data.settings.unitNames.targetClassColored = value;

                if (data.settings.isSymmetric) then
                    Private.EnableSymmetry(data);
                else
                    Private.DisableSymmetry(data);
                end
            end;

            xOffset = function(value)
                data.settings.unitNames.xOffset = value;
                data.player:SetPoint("BOTTOMLEFT", data.left, "TOPLEFT", value, 0);
                data.target:SetPoint("BOTTOMRIGHT", data.right, "TOPRIGHT", -(value), 0);
            end;
        };

        sufGradients = {
            enabled = function(value)
                data.settings.sufGradients.enabled = value;
                self:SetPortraitGradientsEnabled(value);
            end;

            height = function(value)
                data.settings.sufGradients.height = value;

                if (data.settings.sufGradients.enabled and data.gradients) then
                    for _, frame in tk.pairs(data.gradients) do
                        frame:SetSize(100, value);
                    end
                end
            end;

            targetClassColored = function(value)
                data.settings.sufGradients.targetClassColored = value;

                if (data.settings.sufGradients.enabled) then
                    local handler = em:FindHandlerByKey("TargetGradient", "PLAYER_TARGET_CHANGED");

                    if (handler) then
                        handler:Run();
                    end
                end
            end;
        };
    };

    db:RegisterUpdateFunctions("profile.unitPanels", data.updateFunctions, function(func, value)
        if (self:IsEnabled() or func == data.updateFunctions.enabled) then
            func(value);
        end
    end);
end

function C_UnitPanels:OnEnable(data)
    if (data.left) then
        data.left:Show();
        data.right:Show();
        data.center:Show();
        return;
    end

    local r, g, b = tk:GetThemeColor();
    db:AppendOnce(db.profile, "unitPanels.sufGradients", {
        from = {r = r, g = g, b = b, a = 0.5},
        to = {r = 0, g = 0, b = 0, a = 0}
    });

    data.left = _G.CreateFrame("Frame", "MUI_UnitPanelLeft", data.buiContainer);
    data.right = _G.CreateFrame("Frame", "MUI_UnitPanelRight", _G.SUFUnittarget or data.buiContainer);
    data.center = _G.CreateFrame("Frame", "MUI_UnitPanelCenter", data.right);

    data.left:SetFrameStrata("BACKGROUND");
    data.center:SetFrameStrata("BACKGROUND");
    data.right:SetFrameStrata("BACKGROUND");

    data.center:SetPoint("TOPLEFT", data.left, "TOPRIGHT");
    data.center:SetPoint("TOPRIGHT", data.right, "TOPLEFT");
    data.center:SetPoint("BOTTOMLEFT", data.left, "BOTTOMRIGHT");
    data.center:SetPoint("BOTTOMRIGHT", data.right, "BOTTOMLEFT");
    data.center.bg = tk:SetBackground(data.center, tk:GetAssetFilePath("Textures\\BottomUI\\Center"));
end

function C_UnitPanels:SetupUnitNames(data)
    local nameTextureFilePath = tk:GetAssetFilePath("Textures\\BottomUI\\NamePanel");

    data.player = _G.CreateFrame("Frame", "MUI_PlayerName", data.left);
    data.player.bg = tk:SetBackground(data.player, nameTextureFilePath);
    data.player.text = data.player:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    data.player.text:SetJustifyH("LEFT");
    data.player.text:SetWordWrap(false);
    data.player.text:SetPoint("LEFT", 15, 0);

    data.target = _G.CreateFrame("Frame", "MUI_TargetName", data.right);
    data.target.bg = tk:SetBackground(data.target, nameTextureFilePath);
    data.target.text = data.target:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    data.target.text:SetParent(_G.SUFUnittarget or data.buiContainer);
    data.target.text:SetJustifyH("RIGHT");
    data.target.text:SetWordWrap(false);
    data.target.text:SetPoint("RIGHT", data.target, "RIGHT", -15, 0);

    tk:ApplyThemeColor(data.settings.alpha, data.player.bg, data.target.bg);

    tk:FlipTexture(data.target.bg, "HORIZONTAL");
    self:UpdateUnitNameText("player");
end

function C_UnitPanels:OnDisable(data)
    if (not data.left) then return; end

    data.left:Hide();
    data.right:Hide();
    data.center:Hide();

    --    self:SetUnitNamesEnabled(false);
end

function C_UnitPanels:SetUnitNamesEnabled(data, enabled)
    if (enabled) then
        if (not (data.player and data.target)) then
            self:SetupUnitNames(data);
        end

        data.player:Show();
        data.target:Show();

        local handler = em:FindHandlerByKey("PlayerUnitName_LevelUp", "PLAYER_LEVEL_UP");

        if (not handler and not tk:IsPlayerMaxLevel()) then
            handler = em:CreateEventHandler("PLAYER_LEVEL_UP", function(createdHandler)
                self:UpdateUnitNameText("player");

                if (tk:IsPlayerMaxLevel()) then
                    createdHandler:Destroy();
                end
            end);

            handler:SetKey("PlayerUnitName_LevelUp");
        end

        handler = em:FindHandlerByKey("PlayerUnitName_RegenEnabled", "PLAYER_REGEN_ENABLED");

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_REGEN_ENABLED", function()
                self:UpdateUnitNameText("player");
            end);

            handler:SetKey("PlayerUnitName_RegenEnabled");
        end

        handler = em:FindHandlerByKey("PlayerUnitName_RegenDisabled", "PLAYER_REGEN_DISABLED");

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_REGEN_DISABLED", function()
                self:UpdateUnitNameText("player");
            end);

            handler:SetKey("PlayerUnitName_RegenDisabled");
        end

        handler = em:FindHandlerByKey("PlayerUnitName_TargetChanged", "PLAYER_TARGET_CHANGED");

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_TARGET_CHANGED", function()
                if (_G.UnitExists("target")) then
                    self:UpdateUnitNameText("target");
                end
            end);

            handler:SetKey("PlayerUnitName_TargetChanged");
        end
    elseif (data.player and data.target) then
        data.player:Hide();
        data.target:Hide();

        em:DestroyHandlersByKey(
            "PlayerUnitName_LevelUp", "PlayerUnitName_RegenEnabled",
            "PlayerUnitName_RegenDisabled", "PlayerUnitName_TargetChanged");
    end
end

do
    local doubleTextureFilePath = tk:GetAssetFilePath("Textures\\BottomUI\\Double");

    function C_UnitPanels:SetSymmetrical(data, isSymmetric)
        data.left.bg = tk:SetBackground(data.left, doubleTextureFilePath);
        data.right.bg = tk:SetBackground(data.right, doubleTextureFilePath);
        data.right.bg:SetTexCoord(1, 0, 0, 1);

        tk:ApplyThemeColor(data.settings.alpha,
            data.left.bg,
            data.center.bg,
            data.right.bg
        );

        if (isSymmetric) then
            Private.EnableSymmetry(data);
        else
            Private.DisableSymmetry(data);
        end
    end
end

function C_UnitPanels:RepositionPanels(data)
    local actionBarPanel = data.ActionBarPanel:GetPanel();

    if (actionBarPanel) then
        data.left:SetPoint("TOPLEFT", actionBarPanel, "TOPLEFT", 0, data.settings.height);
        data.right:SetPoint("TOPRIGHT", actionBarPanel, "TOPRIGHT", 0, data.settings.height);
    else
        -- Action Bar Panel is disabled...
        local height = data.settings.height;
        local dataTextModule = MayronUI:ImportModule("DataText");

        if (dataTextModule and dataTextModule:IsShown()) then
            local dataTextBar = dataTextModule:GetDataTextBar();
            data.left:SetPoint("TOPLEFT", dataTextBar, "TOPLEFT", 0, height);
            data.right:SetPoint("TOPRIGHT", dataTextBar, "TOPRIGHT", 0, height);

        else
            data.left:SetPoint("TOPLEFT", data.buiContainer, "TOPLEFT", 0, height);
            data.right:SetPoint("TOPRIGHT", data.buiContainer, "TOPRIGHT", 0, height);
        end
    end
end

function C_UnitPanels:UpdateUnitNameText(data, unitType)
    local unitLevel = _G.UnitLevel(unitType);

    local name = _G.UnitName(unitType);
    name = tk.Strings:SetOverflow(name, 22);

    local _, class = _G.UnitClass(unitType); -- not sure if this works..
    local classification = _G.UnitClassification(unitType);

    if (tonumber(unitLevel) < 1) then
        unitLevel = "boss";
    elseif (classification == "elite" or classification == "rareelite") then
        unitLevel = tostring(unitLevel).."+";
    end

    if (classification == "rareelite" or classification == "rare") then
        unitLevel = tk.Strings:Concat("|cffff66ff", unitLevel, "|r");
    end

    if (unitType ~= "player") then
        if (classification == "worldboss") then
            unitLevel = tk.Strings:SetTextColorByRGB(unitLevel, 0.25, 0.75, 0.25); -- yellow
        else
            local color = tk:GetDifficultyColor(_G.UnitLevel(unitType));

            unitLevel = tk.Strings:SetTextColorByRGB(unitLevel, color.r, color.g, color.b);
            name = (_G.UnitIsPlayer(unitType) and tk.Strings:SetTextColorByClass(name, class)) or name;
        end
    else
        unitLevel = tk.Strings:SetTextColorByRGB(unitLevel, 1, 0.8, 0);

        if (_G.UnitAffectingCombat("player")) then
            name = tk.Strings:SetTextColorByRGB(name, 1, 0, 0);
        else
            name = tk.Strings:SetTextColorByClass(name, class);
        end
    end

    data[unitType].text:SetText(tk.string.format("%s %s", name, unitLevel));
end

function Private.CreateGradientFrame(data, parent)
    local frame = _G.CreateFrame("Frame", nil, parent);
    frame:SetPoint("TOPLEFT", 1, -1);
    frame:SetPoint("TOPRIGHT", -1, -1);
    frame:SetFrameLevel(5);
    frame.texture = frame:CreateTexture(nil, "OVERLAY");
    frame.texture:SetAllPoints(frame);
    frame.texture:SetColorTexture(1, 1, 1, 1);
    frame:SetSize(100, data.settings.sufGradients.height);
    frame:Show();

    local from = data.settings.sufGradients.from;
    local to = data.settings.sufGradients.to;

    frame.texture:SetGradientAlpha("VERTICAL",
        to.r, to.g, to.b, to.a,
        from.r, from.g, from.b, from.a);

    return frame;
end

function C_UnitPanels:SetPortraitGradientsEnabled(data, enabled)
    if (not _G.IsAddOnLoaded("ShadowedUnitFrames")) then
        return;
    end

    if (enabled) then
        data.gradients = data.gradients or obj:PopWrapper();

        for _, unitID in obj:IterateArgs("player", "target") do
            local parent = _G["SUFUnit"..unitID];

            if (parent and parent.portrait) then
                data.gradients[unitID] = data.gradients[unitID] or
                    Private.CreateGradientFrame(data, parent);

                if (unitID == "target") then
                    local frame = data.gradients[unitID];
                    local handler = em:FindHandlerByKey("TargetGradient", "PLAYER_TARGET_CHANGED");

                    if (not handler) then
                        handler = em:CreateEventHandler("PLAYER_TARGET_CHANGED", function()
                            if (not _G.UnitExists("target")) then
                                return;
                            end

                            local from = data.settings.sufGradients.from;
                            local to = data.settings.sufGradients.to;

                            if (_G.UnitIsPlayer("target") and data.settings.sufGradients.targetClassColored) then
                                local _, class = _G.UnitClass("target");
                                class = tk.string.upper(class);
                                class = class:gsub("%s+", "");

                                local classColor = tk.Constants.CLASS_COLORS[class];

                                frame.texture:SetGradientAlpha("VERTICAL",
                                    to.r, to.g, to.b, to.a,
                                    classColor.r, classColor.g, classColor.b, from.a);
                            else
                                frame.texture:SetGradientAlpha("VERTICAL",
                                    to.r, to.g, to.b, to.a,
                                    from.r, from.g, from.b, from.a);
                            end
                        end);

                        handler:SetKey("TargetGradient");
                    end

                    handler:Run();
                end

            elseif (data.gradients[unitID]) then
                data.gradients[unitID]:Hide();
            end
        end
    else
        if (data.gradients) then
            for _, frame in tk.pairs(data.gradients) do
                frame:Hide();
            end
        end

        local handler = em:FindHandlerByKey("TargetGradient", "PLAYER_TARGET_CHANGED");

        if (handler) then
            handler:Destroy();
        end
    end
end

-- Private Functions -------------------------

function Private.DetachShadowedUnitFrames()
    local currentProfile = _G.ShadowUF.db:GetCurrentProfile();
    local SUF = _G.ShadowedUFDB["profiles"][currentProfile]["positions"]["targettarget"];

    SUF["point"] = "TOP"; SUF["anchorTo"] = "UIParent";
    SUF["relativePoint"] = "TOP"; SUF["x"] = 0; SUF["y"] = -40;
end

function Private.AttachShadowedUnitFrames(rightPanel)
    local currentProfile = _G.ShadowUF.db:GetCurrentProfile();
    local anchorTo = "UIParent";

    if (tk._G["MUI_UnitPanelCenter"]) then
        anchorTo = "MUI_UnitPanelCenter";
    end

    local SUF = _G.ShadowedUFDB["profiles"][currentProfile]["positions"]["targettarget"];
    SUF["point"] = "TOP"; SUF["anchorTo"] = anchorTo;
    SUF["relativePoint"] = "TOP"; SUF["x"] = 0; SUF["y"] = -40;

    if (_G.SUFUnitplayer) then
        _G.SUFUnitplayer:SetFrameStrata("MEDIUM");
    end

    if (_G.SUFUnittarget) then
        _G.SUFUnittarget:SetFrameStrata("MEDIUM");
        rightPanel:SetFrameStrata("LOW");
    end

    if (_G.SUFUnittargettarget) then
        _G.SUFUnittargettarget:SetFrameStrata("MEDIUM");
    end

    _G.ShadowUF.Layout:Reload();
end

function Private.AnchorGridFrame(settings)
    if (tk.Tables:Contains(settings.gridProfiles, _G.Grid.db:GetCurrentProfile())) then
        _G.GridLayoutFrame:ClearAllPoints();
        _G.GridLayoutFrame:SetPoint(settings.point, settings.target,
            "TOPRIGHT", settings.xOffset, settings.yOffset);
    end
end

do
    local singleTextureFilePath = tk:GetAssetFilePath("Textures\\BottomUI\\Single");

    local function SwitchToSingle(data)
        if (data.target) then
            data.target.text:SetText(tk.Strings.Empty);
        end

        -- If the parent is not SUF it won't hide automatically!
        if (data.right:GetParent() == data.buiContainer) then
            data.right:Hide();
        end

        data.left.bg:SetAlpha(0);
        data.left.noTargetBg:SetAlpha(data.settings.alpha);
    end

    function Private.EnableSymmetry(data)
        tk:ApplyThemeColor(data.settings.alpha, data.left.noTargetBg);

        if (not data.left.noTargetBg) then
            data.left.noTargetBg = tk:SetBackground(data.left, singleTextureFilePath);
        end

        if (data.right:GetParent() == data.buiContainer) then
            data.right:Hide();
        end

        local handler = em:FindHandlerByKey("EnableSymmetry_PLAYER_TARGET_CHANGED");

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_TARGET_CHANGED", function()
                if (_G.UnitExists("target")) then
                    if (data.right:GetParent() == data.buiContainer) then
                        data.right:Show();
                    end

                    data.left.bg:SetAlpha(data.settings.alpha);
                    data.left.noTargetBg:SetAlpha(0);

                    if (data.settings.unitNames.targetClassColored) then
                        if (_G.UnitIsPlayer("target")) then
                            local _, class = _G.UnitClass("target");
                            tk:SetClassColoredTexture(class, data.target.bg);
                        else
                            tk:ApplyThemeColor(data.settings.alpha, data.target.bg);
                        end
                    end
                else
                    SwitchToSingle(data);
                end
            end);

            handler:SetKey("EnableSymmetry_PLAYER_TARGET_CHANGED");
        end

        handler = em:FindHandlerByKey("EnableSymmetry_EnteringWorld", "PLAYER_ENTERING_WORLD");

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_ENTERING_WORLD", function()
                if (not _G.UnitExists("target")) then
                    SwitchToSingle(data);
                end
            end);

            handler:SetKey("EnableSymmetry_EnteringWorld");
        end

        handler:Run();
        em:DestroyHandlersByKey("DisableSymmetry_TargetChanged");
    end

    function Private.DisableSymmetry(data)
        data.right:SetParent(data.buiContainer);

        local handler = em:FindHandlerByKey("DisableSymmetry_TargetChanged", "PLAYER_TARGET_CHANGED");

        if (not data.settings.unitNames.targetClassColored) then
            if (handler) then
                handler:Destroy();
            end

            return;
        end

        if (not handler) then
            handler = em:CreateEventHandler("PLAYER_TARGET_CHANGED", function()
                local targetClassColored = data.settings.unitNames.targetClassColored;

                if (targetClassColored and _G.UnitExists("target") and _G.UnitIsPlayer("target")) then
                    tk:SetClassColoredTexture(_G.UnitClass("target"), data.target.bg);
                else
                    tk:ApplyThemeColor(data.settings.alpha, data.target.bg);
                end
            end);

            handler:SetKey("DisableSymmetry_TargetChanged");
        end

        handler:Run();
        em:DestroyHandlersByKey("EnableSymmetry_PLAYER_ENTERING_WORLD", "EnableSymmetry_EnteringWorld");
    end
end