-- luacheck: ignore MayronUI self 143 631
local MayronUI = _G.MayronUI;
local tk, db, em, gui, obj, L = MayronUI:GetCoreComponents(); -- luacheck: ignore

-- Register and Import Modules -----------

local C_Tutorial = MayronUI:RegisterModule("TutorialModule", "Tutorial");
local GetAddOnMetadata = _G.GetAddOnMetadata;

function C_Tutorial:OnInitialize()
  local show = tk:GetTutorialShowState(db.profile.installMessage);

  if (show) then
    self:SetEnabled(true);
  end
end

function C_Tutorial:OnEnable()
  local frame = tk:PopFrame("Frame");
  frame:SetFrameStrata("TOOLTIP");
  frame:SetSize(350, 230);
  frame:SetPoint("CENTER");

  gui:CreateDialogBox(tk.Constants.AddOnStyle, nil, nil, frame);
  gui:AddCloseButton(tk.Constants.AddOnStyle, frame);

  local version = GetAddOnMetadata("MUI_Core", "Version");

  local title = tk.Strings:Concat(L["Version"], "[", version, "]");
  gui:AddTitleBar(tk.Constants.AddOnStyle, frame, title);

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
  tk:SetFontSize(frame.text, 14);
  frame.text:SetWordWrap(true);
  frame.text:SetPoint("TOPLEFT", 10, -40);
  frame.text:SetPoint("TOPRIGHT", -10, -40);

  local tutorialMessage = L["Thank you for installing %s!\n\nYou can fully customise the UI using the config menu:"];
  tutorialMessage = tutorialMessage:format("MayronUI");

  local subMessage = tk.Strings:SetTextColorByKey(L["(type '/mui' to list all slash commands)"], "GOLD");

  frame.text:SetText(tk.Strings:Join("\n\n", tutorialMessage, subMessage));

  local configButton = gui:CreateButton(tk.Constants.AddOnStyle, frame, "Open Config Menu");
  configButton:SetPoint("TOP", frame.text, "BOTTOM", 0, -20);
  configButton:SetScript("OnClick", function()
    MayronUI:TriggerCommand("config");
    frame:Hide();
    db.profile.installMessage = version;
  end);

  local website = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
  website:SetPoint("TOP", configButton, "BOTTOM", 0, -15);
  tk:SetFontSize(website, 20);
  website:SetText(tk.Strings:SetTextColorByKey("https://mayronui.com", "LIGHT_YELLOW"));

  frame.closeBtn:HookScript("OnClick", function()
    db.profile.installMessage = version;
  end);
end