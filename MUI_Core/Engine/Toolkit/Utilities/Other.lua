-- luacheck: ignore LibStub self 143 631
local _, namespace = ...;

local string, tostring, select, unpack, type = _G.string, _G.tostring, _G.select, _G.unpack, _G.type;
local tonumber, math, pairs, pcall, error = _G.tonumber, _G.math, _G.pairs, _G.pcall, _G.error;
local hooksecurefunc, UnitLevel, UnitClass = _G.hooksecurefunc, _G.UnitLevel, _G.UnitClass;
local GetMaxPlayerLevel, tostringall = _G.GetMaxPlayerLevel, _G.tostringall;
local UnitQuestTrivialLevelRange, GetQuestGreenRange = _G.UnitQuestTrivialLevelRange, _G.GetQuestGreenRange;

local obj = namespace.components.Objects; ---@type MayronObjects
local tk = namespace.components.Toolkit; ---@type Toolkit
local L = namespace.components.Locale;

function tk.Numbers:ToPrecision(number, precision)
  number = tonumber(number);
  number = math.floor(number * (math.pow(10, precision)) + 0.5);
  number = number / (math.pow(10, precision));
  return number;
end

function tk:ValueIsEither(value, ...)
  for i = 1, select("#", ...) do
    local otherValue = (select(i, ...));
    if (self:Equals(value, otherValue)) then
      return true;
    end
  end

  return false;
end

function tk:UnpackIfTable(value)
  if (obj:IsTable(value)) then
    return obj:UnpackTable(value);
  else
    return value;
  end
end

function tk:Print(...)
  local prefix = self.Strings:SetTextColorByTheme("MayronUI:");
  _G.DEFAULT_CHAT_FRAME:AddMessage(string.join(" ", prefix, tostringall(...)));
end

function tk:GetAssetFilePath(filePath)
  return string.format("%s\\%s", tk.Constants.ASSETS_FOLDER, filePath);
end

do
  local IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown =
    _G.IsShiftKeyDown, _G.IsControlKeyDown, _G.IsAltKeyDown;

  local modKeys = {
    S = function() return IsShiftKeyDown(); end;
    C = function() return IsControlKeyDown(); end;
    A = function() return IsAltKeyDown(); end;
  };

  function tk:IsModComboActive(strKey) -- "SC" - is shift and control down but not alt? (example)
    for i = 1, #strKey do
      local modCode = strKey:sub(i,i);
      modCode = string.upper(modCode);

      -- If unknown mod key, skip it because it's from an old bug (russian locale accidentally added to db)
      if (obj:IsFunction(modKeys[modCode]) and not modKeys[modCode]()) then
        return false;
      end
    end

    return strKey ~= tk.Strings.Empty;
  end
end

do
  local function GetPlayerLevelRange()
    if (GetQuestGreenRange) then
      return GetQuestGreenRange();
    end

    if (UnitQuestTrivialLevelRange) then
      return UnitQuestTrivialLevelRange("player");
    end

    return 5;
  end

  function tk:GetDifficultyColor(level)
    local difference = (level - UnitLevel("player"));
    local color;

    if (difference >= 5) then
      color = _G.QuestDifficultyColors["impossible"];

    elseif (difference >= 3) then
      color = _G.QuestDifficultyColors["verydifficult"];

    elseif (difference >= -2 or level < 0) then
      color = _G.QuestDifficultyColors["difficult"];

    elseif (-difference <= GetPlayerLevelRange()) then
      color = _G.QuestDifficultyColors["standard"];

    else
      color = _G.QuestDifficultyColors["trivial"];
    end

    return color;
  end
end

function tk:Equals(value1, value2, deepEquals)
    local type1 = type(value1);

    if (type(value2) == type1) then

        if (type1 == "table") then
            if (not deepEquals) then
                return tostring(value1) == tostring(value2);
            else
                for id, value in pairs(value1) do
                    if (not self:Equals(value, value2[id])) then
                        return false;
                    end
                end
            end

            return true;
        elseif (type1 == "function") then
            return tostring(value1) == tostring(value2);
        else
            return value1 == value2;
        end
    end

    return false;
end

function tk:GetPlayerKey()
    local key, realm = _G.UnitName("player"), _G.GetRealmName():gsub("%s+", "");
    key = realm and string.join("-", key, realm);
    return key;
end

do
  local GetLocale = _G.GetLocale;

  function tk:IsLocale(...)
    for _, locale in obj:IterateArgs(...) do
      if (GetLocale() == locale) then
        return true;
      end
    end

    return false;
  end
end

function tk:IsPlayerMaxLevel()
    local playerLevel = UnitLevel("player");
    return (GetMaxPlayerLevel() == playerLevel);
end

-- the class filename is often required for use with the API (unlike the localized class name)
function tk:GetClassFileNameByUnitID(unitID)
  local _, classFilename, _ = UnitClass(unitID); -- className, classFilename, classID
  return classFilename;
end

-- the class name to be shown on the UI (not usable with the API)
function tk:GetLocalizedClassNameByFileName(classFileName, makeClassColored)
  classFileName = classFileName:gsub("%s+", tk.Strings.Empty):upper();
  
  local localizedName = 
    tk.Constants.LOCALIZED_CLASS_NAMES[classFileName] or 
    tk.Constants.LOCALIZED_CLASS_FEMALE_NAMES[classFileName];

  tk:Assert(localizedName, "Unknown class file name '%s'.", classFileName);

  if (makeClassColored) then
    localizedName = tk.Strings:SetTextColorByClassFileName(localizedName, classFileName);
  end

  return localizedName;
end

function tk:GetClassColorByUnitID(unitID)
  local classFileName = tk:GetClassFileNameByUnitID(unitID);
  return _G.GetClassColorObj(classFileName);
end

local errorInfo = {};
errorInfo.PREFIX = "|cff00ccffMayronUI: |r";

-- @param silent (boolean) - true if errors should be cause in the error log instead of triggering.
function tk:SetSilentErrors(silent)
    errorInfo.silent = silent;
end

-- @return errorLog (table) - contains index/string pairs of errors caught while in silent mode.
function tk:GetErrorLog()
    errorInfo.errorLog = errorInfo.errorLog or {};
    return errorInfo.errorLog;
end

-- empties the error log table.
function tk:FlushErrorLog()
    if (errorInfo.errorLog) then
        tk.Tables:Empty(errorInfo.errorLog);
    end
end

-- @return numErrors (number) - the total number of errors caught while in silent mode.
function tk:GetNumErrors()
    return (errorInfo.errorLog and #errorInfo.errorLog) or 0;
end

function tk:Assert(condition, errorMessage, ...)
  if (condition) then return end

  if ((select("#", ...)) >= 1) then
    errorMessage = string.format(errorMessage, tostringall(...));

  elseif (tk.Strings:Contains(errorMessage, "%s")) then
    errorMessage = string.format(errorMessage, "nil");
  end

  local fullError = tk.Strings:Join(tk.Strings.Empty, errorInfo.PREFIX, errorMessage);

  if (errorInfo.silent) then
    errorInfo.errorLog = errorInfo.errorLog or {};
    errorInfo.errorLog[#errorInfo.errorLog + 1] = pcall(function() error(fullError) end);
  else
    error(fullError);
  end
end

function tk:Error(errorMessage, ...)
    self:Assert(false, errorMessage, ...);
end

do
    local POPUP_GLOBAL_NAME = "MUI_TOOLKIT_POPUP";

    local function EditBox_OnEscapePressed(self)
        local popup = self.popup or self;
        local editBox = popup.editBox;
        local onCancel = popup.data.OnCancel;

        if (onCancel) then
            onCancel(editBox, editBox:GetText());
        end

        _G.StaticPopup_Hide(POPUP_GLOBAL_NAME);
    end

    local function EditBox_OnEnterPressed(self)
        local popup = self.popup or self;
        local editBox = popup.editBox;
        local validator = popup.data.OnValidate;
        local onAccept = popup.data.OnAccept;

        if (validator and not validator(editBox, editBox:GetText())) then
          return;
        end

        if (onAccept) then
          local args = popup.data.args;
          popup.data.args = nil;
          onAccept(editBox, editBox:GetText(), obj:UnpackTable(args));
        end

        _G.StaticPopup_Hide(POPUP_GLOBAL_NAME);
    end

    local function EditBox_OnTextChanged(self, userInput)
      if (not obj:IsTable(self.popup.data)) then return end
      local validator = self.popup.data.OnValidate;

      if (not userInput or not validator) then return end

      local isValid = validator(self, self:GetText());
      self.popup.button1:SetEnabled(isValid);
    end

    local function PopUp_OnShow(self)
      if (self.button1) then
        self.button1:Enable();
      end

      if (self.button2) then
        self.button2:Enable();
      end

      if (not self.editBox) then return end

      self.editBox.popup = self; -- refer back to popup in scripts below

      if (self.data and self.data.editBoxText) then
        self.editBox:SetText(self.data.editBoxText);
        self.editBox:HighlightText();
        self.editBox:SetWidth(300);
      end

      self.editBox:SetFocus();
      self.editBox:SetScript("OnEscapePressed", EditBox_OnEscapePressed);
      self.editBox:SetScript("OnEnterPressed", EditBox_OnEnterPressed);
      self.editBox:SetScript("OnTextChanged", EditBox_OnTextChanged);

      EditBox_OnTextChanged(self.editBox, true); -- call it OnShow to enable/disable confirm button
    end

    local function PopUp_OnAccept(self)
      if (self.data.OnAccept) then
        if (self.hasEditBox) then
          EditBox_OnEnterPressed(self);
        else
          local args = self.data.args;
          self.data.args = nil;
          self.data.OnAccept(self, obj:UnpackTable(args));
        end
      end
    end

    local function GetPopup(message, subMessage)
      local popup = _G.StaticPopupDialogs[POPUP_GLOBAL_NAME];

      if (not popup) then
        popup = {
          preferredIndex = 3;
          timeout = 0;
          whileDead = 1;
          hideOnEscape = 1;
          maxLetters = 1024;
          OnShow = PopUp_OnShow;
          closeButton = true;
          data = obj:PopTable();
        };

        _G.StaticPopupDialogs[POPUP_GLOBAL_NAME] = popup;
      end

      popup.text = message;
      popup.subText = subMessage;

      return popup;
    end

    local function StoreArgs(popup, ...)
      if (select("#", ...) > 0) then
        popup.data.args = obj:PopTable(...);
      end
    end

    local function ShowConfirmPopup(message, subMessage, onConfirm, confirmText, onCancel, cancelText, isWarning, ...)
      local popup = GetPopup(message, subMessage);

      popup.hasEditBox = false;
      popup.button1 = confirmText or L["Confirm"];
      popup.button2 = cancelText or L["Cancel"];
      popup.OnAccept = PopUp_OnAccept;
      popup.OnCancel = onCancel;

      if (isWarning) then
        popup.showAlert = true;
      end

      popup.data.OnAccept = onConfirm;
      popup.data.OnValidate = nil;
      StoreArgs(popup, ...);

      return popup;
    end

    function tk:ShowConfirmPopup(...)
      local popup = ShowConfirmPopup(...);
      _G.StaticPopup_Show(POPUP_GLOBAL_NAME, nil, nil, popup.data);
    end

    function tk:ShowConfirmPopupWithInsertedFrame(insertedFrame, ...)
      local popup = ShowConfirmPopup(...);
      _G.StaticPopup_Show(POPUP_GLOBAL_NAME, nil, nil, popup.data, insertedFrame);
    end

    function tk:ShowMessagePopup(message, subMessage, okayText, onOkay, isWarning, ...)
      local popup = GetPopup(message, subMessage);

      popup.button1 = okayText or L["Okay"];
      popup.button2 = nil;
      popup.hasEditBox = false;
      popup.OnAccept = onOkay;
      popup.OnCancel = nil;
      StoreArgs(popup, ...);

      if (isWarning) then
        popup.showAlert = true;
      end

      _G.StaticPopup_Show(POPUP_GLOBAL_NAME, nil, nil, popup.data);
    end

    function tk:ShowInputPopupWithOneButton(message, subMessage, editBoxText, okayText, ...)
      local popup = GetPopup(message, subMessage);

      popup.button1 = okayText or L["Okay"];
      popup.button2 = nil;
      popup.hasEditBox = true;
      popup.OnAccept = EditBox_OnEnterPressed;
      popup.OnCancel = nil;

      popup.data.editBoxText = editBoxText;
      popup.data.OnAccept = nil;
      popup.data.OnCancel = nil;
      popup.data.OnValidate = nil;
      StoreArgs(popup, ...);

      _G.StaticPopup_Show(POPUP_GLOBAL_NAME, nil, nil, popup.data);
  end

  function tk:ShowInputPopup(message, subMessage, editBoxText, onValidate, confirmText, onConfirm, cancelText, onCancel, isWarning, ...)
    local popup = GetPopup(message, subMessage);

    popup.button1 = confirmText or L["Confirm"];
    popup.button2 = cancelText or L["Cancel"];
    popup.hasEditBox = true;
    popup.OnAccept = EditBox_OnEnterPressed;
    popup.OnCancel = EditBox_OnEscapePressed;

    if (isWarning) then
      popup.showAlert = true;
    end

    popup.data.editBoxText = editBoxText;
    popup.data.OnAccept = onConfirm;
    popup.data.OnCancel = onCancel;
    popup.data.OnValidate = onValidate;
    StoreArgs(popup, ...);

    _G.StaticPopup_Show(POPUP_GLOBAL_NAME, nil, nil, popup.data);
  end
end

do
    local callbacks = {};

    local function CreateCallbackWrapper(key, tbl, methodName)
      return function(...)
        local callbackData = callbacks[key];

        if (not callbackData) then
          return; -- it has been unhooked
        end

        local args = obj:PopTable();
        tk.Tables:AddAll(args, select(2, unpack(callbackData)));
        tk.Tables:AddAll(args, ...);

        if (obj:IsTable(callbackData)) then
          -- pass to callback function all custom args and then the real hooksecurefunc args
            local callback = callbackData[1];

            if (obj:IsFunction(callback)) then
              local unhook = callbackData[1](unpack(args));

              if (unhook) then
                if (tbl) then
                  tk:UnhookFunc(tbl, methodName, callbackData[1]);
                else
                  tk:UnhookFunc(methodName, callbackData[1]);
                end
              end
            end
          end

          obj:PushTable(args);
        end
    end

    function tk:HookFunc(tbl, methodName, callback, ...)
      if (obj:IsString(tbl)) then
        local realGlobalMethodName = tbl;
        local realCallback = methodName;
        local firstArg = callback;

        local key = string.format("%s|%s", realGlobalMethodName, tostring(realCallback));
        local callbackWrapper = CreateCallbackWrapper(key, tbl, methodName);

        callbacks[key] = obj:PopTable(realCallback, firstArg, ...);
        hooksecurefunc(realGlobalMethodName, callbackWrapper);
        return realCallback;
      else
        local key = string.format("%s|%s|%s", tostring(tbl), methodName, tostring(callback));
        local callbackWrapper = CreateCallbackWrapper(key, tbl, methodName);

        callbacks[key] = obj:PopTable(callback, ...);
        hooksecurefunc(tbl, methodName, callbackWrapper);
        return callback;
      end
    end

    function tk:UnhookFunc(tbl, methodName, callback)
        local key;

        if (obj:IsString(tbl)) then
            local realGlobalMethodName = tbl;
            local realCallback = methodName;
            key = string.format("%s|%s", realGlobalMethodName, tostring(realCallback));
        else
            key = string.format("%s|%s|%s", tostring(tbl), methodName, tostring(callback));
        end

        if (obj:IsTable(callbacks[key])) then
          obj:PushTable(callbacks[key]);
        end

        callbacks[key] = nil;
    end
end

do
  local BNGetFriendInfoByID, C_BattleNet = _G.BNGetFriendInfoByID, _G.C_BattleNet;
  local strsplit = _G.strsplit;

  function tk.ReplaceAccountNameCodeWithBattleTag(accountNameCode)
    for i = 1, 200 do
      if (BNGetFriendInfoByID) then
        -- otherAccountNameCode will be a code such as |Km24|k
        local _, otherAccountNameCode, battleTag = BNGetFriendInfoByID(i);

        if (i > 50 and not otherAccountNameCode) then
          return "";
        end

        if (accountNameCode == otherAccountNameCode) then
          return (select(1, strsplit("#", battleTag)));
        end

      elseif (C_BattleNet and C_BattleNet.GetAccountInfoByID) then
        local friendInfo = C_BattleNet.GetAccountInfoByID(i);

        if (obj:IsTable(friendInfo)) then
          if (i > 50 and not friendInfo.accountName) then
            return "";
          end

          if (accountNameCode == friendInfo.accountName) then
            return (select(1, strsplit("#", friendInfo.battleTag)));
          end
        end
      end
    end
  end
end

local GetAddOnMetadata = _G.GetAddOnMetadata;

function tk:GetTutorialShowState(oldVersion, afterInstall)
  local currentVersion = GetAddOnMetadata("MUI_Core", "Version");
  local major, minor, patch = tk.Strings:Split(currentVersion, ".");
  major = tonumber(major);
  minor = tonumber(minor);
  patch = tonumber(patch);

  local shouldShow = false;

  if (not oldVersion or not (obj:IsString(oldVersion))) then
    shouldShow = true;
  else
    local oldMajor, oldMinor, oldPatch = tk.Strings:Split(oldVersion, ".");
    oldMajor = tonumber(oldMajor);
    oldMinor = tonumber(oldMinor);
    oldPatch = tonumber(oldPatch);

    if (major > oldMajor or minor > oldMinor or patch > (oldPatch + 5)) then
      shouldShow = true;
    end
  end

  if (shouldShow and afterInstall) then
    local freshInstall = _G.MayronUI.db.profile.freshInstall;
    if (not freshInstall) then
      shouldShow = false;
    end
  end

  return shouldShow;
end

function tk:GetVersion(colorKey)
  local client = tk.Strings.Empty;

  if (tk:IsRetail()) then
    client = "-retail";
  elseif (tk:IsWrathClassic()) then
    client = "-wrath";
  elseif (tk:IsBCClassic()) then
    client = "-bcc";
  elseif (tk:IsClassic()) then
    client = "-classic";
  end

  local muiCore = GetAddOnMetadata("MUI_Core", "Version");
  local muiConfig = GetAddOnMetadata("MUI_Config", "Version");
  local muiSetup = GetAddOnMetadata("MUI_Setup", "Version");
  local version;

  if (muiCore == muiConfig and muiConfig == muiSetup) then
     version = string.format("%s%s", muiCore, client);
  else
    muiCore = string.format("%s%s", muiCore, client);
    muiConfig = string.format("%s%s", muiConfig, client);
    muiSetup = string.format("%s%s", muiSetup, client);
    version = string.format("MUI_Core: %s, MUI_Config: %s, MUI_Setup: %s", muiCore, muiConfig, muiSetup);
  end

  version = tk.Strings:SetTextColorByKey(version, colorKey or "GRAY");

  return version;
end

-- "Mix two colors together in variable proportion."
-- Used to get color from a gradient between two colors based on a percentage.
-- percent should be between 0 and 1 - "a percentage balance point between the two colors"
function tk:MixColorsByPercentage(color1, color2, percentage)
  local weight;

  if (percentage > 0.5) then
  -- more than half way to the end of the gradient.
		weight = (percentage * 2) - 1; -- 0.02-0.98
	else
    weight = (percentage * 2); -- 0.02-1
	end

  -- algorithm from:
  -- https://stackoverflow.com/questions/30143082/how-to-get-color-value-from-gradient-by-percentage-with-javascript
  local r = (color1.r * weight) + (color2.r * (1 - weight));
  local g = (color1.g * weight) + (color2.g * (1 - weight));
  local b = (color1.b * weight) + (color2.b * (1 - weight));

	return r, g, b;
end

do
  local classes = tk.Constants.CLASS_FILE_NAMES;

  local function IsClass(unitID, classFileName)
    unitID = unitID or "player";
    local _, _, classId = UnitClass(unitID);
    local playerClass = tk.Constants.CLASS_IDS[classId];
    return playerClass == classFileName;
  end

  function tk:IsWarrior(unitID)
    return IsClass(unitID, classes.WARRIOR);
  end

  function tk:IsPaladin(unitID)
    return IsClass(unitID, classes.PALADIN);
  end

  function tk:IsHunter(unitID)
    return IsClass(unitID, classes.HUNTER);
  end

  function tk:IsRogue(unitID)
    return IsClass(unitID, classes.ROGUE);
  end

  function tk:IsPriest(unitID)
    return IsClass(unitID, classes.PRIEST);
  end

  function tk:IsDeathKnight(unitID)
    return IsClass(unitID, classes.DEATHKNIGHT);
  end

  function tk:IsShaman(unitID)
    return IsClass(unitID, classes.SHAMAN);
  end

  function tk:IsMage(unitID)
    return IsClass(unitID, classes.MAGE);
  end

  function tk:IsWarlock(unitID)
    return IsClass(unitID, classes.WARLOCK);
  end

  function tk:IsMonk(unitID)
    return IsClass(unitID, classes.MONK);
  end

  function tk:IsDruid(unitID)
    return IsClass(unitID, classes.DRUID);
  end

  function tk:IsDemonHunter(unitID)
    return IsClass(unitID, classes.DEMONHUNTER);
  end
end