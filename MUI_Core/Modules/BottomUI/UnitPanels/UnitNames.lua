-- luacheck: ignore self 143 631
local MayronUI = _G.MayronUI;
local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents(); -- luacheck: ignore
local _, C_UnitPanels = _G.MayronUI:ImportModule("UnitPanels");

local CreateFrame, UnitGUID, UnitAffectingCombat = _G.CreateFrame, _G.UnitGUID, _G.UnitAffectingCombat;
local UnitExists, IsResting, GetRestState = _G.UnitExists, _G.IsResting, _G.GetRestState;

local function UpdateUnitNameText(data, unitID)
  local unitNameText = tk.Strings:GetUnitFullNameText(unitID);

  if (unitID:lower() == "player") then
    if (UnitAffectingCombat("player")) then
      tk:SetBasicTooltip(data[unitID], _G.COMBAT, "ANCHOR_CURSOR");

    elseif (IsResting()) then
      local _, exhaustionStateName = GetRestState();
      tk:SetBasicTooltip(data[unitID], exhaustionStateName, "ANCHOR_CURSOR");

    else
      tk:SetBasicTooltip(data[unitID], nil, "ANCHOR_CURSOR");
    end
  end

  data[unitID].text:SetText(unitNameText);
end

function C_UnitPanels:SetUnitNamesEnabled(data, enabled)
  if (enabled) then
    if (not (data.player and data.target)) then
      self:SetUpUnitNames(data);
    else
      em:EnableEventListeners(
        "MuiUnitNames_LevelUp",
        "MuiUnitNames_UpdatePlayerName",
        "MuiUnitNames_TargetChanged");
    end

    data.player:Show();
    data.target:Show();

  elseif (data.player and data.target) then
    data.player:Hide();
    data.target:Hide();

    em:DisableEventHandlers(
      "MuiUnitNames_LevelUp",
      "MuiUnitNames_UpdatePlayerName",
      "MuiUnitNames_TargetChanged");
  end
end

function C_UnitPanels:SetUpUnitNames(data)
  local nameTextureFilePath = tk:GetAssetFilePath("Textures\\BottomUI\\NamePanel");

  data.player = CreateFrame("Frame", "MUI_PlayerName", data.left);
  data.player.bg = tk:SetBackground(data.player, nameTextureFilePath);
  data.player.text = data.player:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
  data.player.text:SetJustifyH("LEFT");
  data.player.text:SetWordWrap(false);
  data.player.text:SetPoint("LEFT", 15, 0);

  data.target = CreateFrame("Frame", "MUI_TargetName", data.right);
  data.target.bg = tk:SetBackground(data.target, nameTextureFilePath);
  data.target.text = data.target:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
  data.target.text:SetJustifyH("RIGHT");
  data.target.text:SetWordWrap(false);
  data.target.text:SetPoint("RIGHT", data.target, "RIGHT", -15, 0);

  tk:ApplyThemeColor(data.settings.alpha, data.player.bg, data.target.bg);

  tk:FlipTexture(data.target.bg, "HORIZONTAL");
  UpdateUnitNameText(data, "player");

  -- Setup event handlers:
  if (not tk:IsPlayerMaxLevel()) then
    local listener = em:CreateEventListenerWithID("MuiUnitNames_LevelUp", function(listener, _, newLevel)
      UpdateUnitNameText(data, "player", newLevel);

      if (UnitGUID("player") == UnitGUID("target")) then
        UpdateUnitNameText(data, "target", newLevel);
      end

      if (tk:IsPlayerMaxLevel()) then
        listener:Destroy();
      end
    end);

    listener:RegisterEvent("PLAYER_LEVEL_UP");
  end

  local listener = em:CreateEventListenerWithID("MuiUnitNames_UpdatePlayerName", function()
    UpdateUnitNameText(data, "player");
  end);

  listener:RegisterEvents(
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "PLAYER_FLAGS_CHANGED");

  listener = em:CreateEventListenerWithID("MuiUnitNames_TargetChanged", function()
    if (UnitExists("target")) then
      UpdateUnitNameText(data, "target");
    else
      data.target.text:SetText(tk.Strings.Empty);
    end

    data:Call("UpdateVisuals", data.target, data.settings.alpha);
  end);

  listener:RegisterEvents("PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD");
end